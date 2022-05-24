// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/token/ERC20/SafeERC20.sol";
import "@openzeppelin/math/SafeMath.sol";
import "@openzeppelin/access/Ownable.sol";
import "../Interfaces/IWETH.sol";
import "../Interfaces/ILendingRegistry.sol";
import "../Interfaces/ILendingLogic.sol";
import "../Interfaces/IPieRegistry.sol";
import "../Interfaces/IPie.sol";
import "../Interfaces/IUniV3Router.sol";

pragma experimental ABIEncoderV2;

/**
 * @title SimpleUniRecipe contract for BaoFinance's Baskets Protocol (PieDAO fork)
 *
 * @author vex
 */
contract SimpleUniRecipe is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // -------------------------------
    // CONSTANTS
    // -------------------------------

    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ILendingRegistry immutable lendingRegistry;
    IPieRegistry immutable basketRegistry;

    // -------------------------------
    // VARIABLES
    // -------------------------------

    uniV3Router uniRouter;
    uniOracle oracle;

    /**
     * Create a new StableUniRecipe.
     *
     * @param _lendingRegistry LendingRegistry address
     * @param _pieRegistry PieRegistry address
     * @param _uniV3Router Uniswap V3 Router address
     */
    constructor(
        address _lendingRegistry,
        address _pieRegistry,
        address _uniV3Router,
        address _uniOracle
    ) {
        require(_lendingRegistry != address(0), "LENDING_MANAGER_ZERO");
        require(_pieRegistry != address(0), "PIE_REGISTRY_ZERO");

        lendingRegistry = ILendingRegistry(_lendingRegistry);
        basketRegistry = IPieRegistry(_pieRegistry);

        uniRouter = uniV3Router(_uniV3Router);
        oracle = uniOracle(_uniOracle);

        // Approve max USDC spending on Curve Exchange
        USDC.approve(address(uniRouter), type(uint256).max);
        // Approve max WETH spending on Uni Router
        WETH.approve(address(uniRouter), type(uint256).max);
    }

    // -------------------------------
    // PUBLIC FUNCTIONS
    // -------------------------------

    /**
     * External bake function.
     * Mints `_mintAmount` basket tokens with as little of `_maxInput` as possible.
     *
     * @param _basket Address of basket token to mint
     * @param _maxInput Max USDC to use to mint _mintAmount basket tokens
     * @param _mintAmount Target amount of basket tokens to mint
     * @return inputAmountUsed Amount of USDC used to mint the basket token
     * @return outputAmount Amount of basket tokens minted
     */
    function bake(
        address _basket,
        uint256 _maxInput,
        uint256 _mintAmount
    ) external returns (uint256 inputAmountUsed, uint256 outputAmount) {
        // Transfer USDC to the Recipe
        USDC.safeTransferFrom(msg.sender, address(this), _maxInput);

        // Bake _mintAmount basket tokens
        outputAmount = _bake(_basket, _mintAmount);

        // Transfer remaining USDC to msg.sender
        uint256 remainingInputBalance = USDC.balanceOf(address(this));
        if (remainingInputBalance > 0) {
            USDC.transfer(msg.sender, remainingInputBalance);
        }
        inputAmountUsed = _maxInput - remainingInputBalance;

        // Transfer minted basket tokens to msg.sender
        IERC20(_basket).safeTransfer(msg.sender, outputAmount);
    }

    /**
     * Bake a basket with ETH.
     * Wraps the ETH that was sent, swaps it for USDC on UniV3, and continues the baking
     * process as normal
     *
     * @param _basket Basket token to mint
     * @param _mintAmount Target amount of basket tokens to mint
     */
    function toBasket(address _basket, uint256 _mintAmount) external payable {        
	// Wrap ETH
        WETH.deposit{value : msg.value}();

        // Form WETH -> USDC swap params
        _swap(
            address(WETH),
            address(USDC),
            getPrice(_basket, _mintAmount),
            500
        );

        // Bake basket
        uint256 outputAmount = _bake(_basket, _mintAmount);

        // Send remaining USDC to msg.sender
        uint256 usdcBalance = USDC.balanceOf(address(this));
        if (usdcBalance > 0) {
            USDC.safeTransfer(msg.sender, usdcBalance);
        }

        // Transfer minted baskets to msg.sender
        IERC20(_basket).safeTransfer(msg.sender, outputAmount);
    }

    /**
     * Get the price of `_amount` basket tokens in USDC
     *
     * @param _basket Basket token to get the price of
     * @param _amount Amount of basket tokens to get price of
     * @return _price Price of `_amount` basket tokens in USDC
     */
    function getPrice(address _basket, uint256 _amount) public returns (uint256 _price) {
        // Check that _basket is a valid basket
        require(basketRegistry.inRegistry(_basket));

        // Loop through all the tokens in the basket and get their prices on UniSwap V3
        (address[] memory tokens, uint256[] memory amounts) = IPie(_basket).calcTokensForAmount(_amount);
        address _token;
        address _underlying;
        uint256 _amount;
        for (uint256 i; i < tokens.length; ++i) {
            _token = tokens[i];
            _amount = amounts[i];

            // If the amount equals zero, revert.
            assembly {
                if iszero(_amount) {
                    revert(0, 0)
                }
            }

            _underlying = lendingRegistry.wrappedToUnderlying(_token);
            if (_underlying != address(0)) {
                _amount = mulDivDown(
                    _amount,
                    getLendingLogicFromWrapped(_token).exchangeRateView(_token),
                    1e18
                );
                _token = _underlying;
            }

            // If the token is USDC, we don't need to perform a swap before lending.
            _price += _token == address(USDC) ? _amount : _quoteExactOutput(address(USDC), _token, _amount, 500);
        }
        return _price;
    }

    /**
     * Get the price of `_amount` basket tokens in ETH
     *
     * @param _basket Basket token to get the price of
     * @param _amount Amount of basket tokens to get price of
     * @return _price Price of `_amount` basket tokens in ETH
     */
    function getPriceEth(address _basket, uint256 _amount) external returns (uint256 _price) {
        _price = _quoteExactOutput(
            address(WETH),
            address(USDC),
            getPrice(_basket, _amount),
            500
        );
    }

    // -------------------------------
    // INTERNAL FUNCTIONS
    // -------------------------------

    /**
     * Internal bake function.
     * Checks if _outputToken is a valid basket, mints _mintAmount basketTokens, and returns the real
     * amount minted.
     *
     * @param _basket Address of basket token to mint
     * @param _mintAmount Target amount of basket tokens to mint
     * @return outputAmount Amount of basket tokens minted
     */
    function _bake(address _basket, uint256 _mintAmount) internal returns (uint256 outputAmount) {
        require(basketRegistry.inRegistry(_basket));
        
        swapAndJoin(_basket, _mintAmount);

        outputAmount = IERC20(_basket).balanceOf(address(this));
    }

    /**
     * Swap for the underlying assets of a basket using only Uni V3 and mint _outputAmount basket tokens.
     *
     * @param _basket Basket to pull underlying assets from
     * @param _mintAmount Target amount of basket tokens to mint
     */
    function swapAndJoin(address _basket, uint256 _mintAmount) internal {
        IPie basket = IPie(_basket);
        (address[] memory tokens, uint256[] memory amounts) = basket.calcTokensForAmount(_mintAmount);

        // Instantiate empty variables that will be assigned multiple times in the loop, less memory allocation
        address _token;
        address underlying;
        uint256 _amount;
        uint256 underlyingAmount;
        ILendingLogic lendingLogic;

        for (uint256 i; i < tokens.length; ++i) {
            _token = tokens[i];
            _amount = amounts[i];

            // If the token is registered in the lending registry, swap to
            // its underlying token and lend it.
            underlying = lendingRegistry.wrappedToUnderlying(_token);

            if (underlying == address(0) && _token != address(USDC)) {
                _swap(
                    address(USDC),
                    _token,
                    _amount,
                    500
                );
            } else {
                // Get underlying amount according to the exchange rate
                lendingLogic = getLendingLogicFromWrapped(_token);
                underlyingAmount = mulDivDown(_amount, lendingLogic.exchangeRate(_token), 1e18);

                // Swap for the underlying asset on UniV3
                // If the token is USDC, no need to swap
                if (underlying != address(USDC)) {
                    _swap(
                        address(USDC),
                        underlying,
                        underlyingAmount,
                        500
                    );
                }

                // Execute lending transactions
                (address[] memory targets, bytes[] memory data) = lendingLogic.lend(underlying, underlyingAmount, address(this));
                for (uint256 j; j < targets.length; ++j) {
                    (bool success,) = targets[j].call{value : 0}(data[j]);
                    require(success, "CALL_FAILED");
                }
            }

            IERC20(_token).approve(_basket, _amount);
        }
        basket.joinPool(_mintAmount);
    }

    /**
     * Swap `_from` -> `_to` and receive exactly `_amountOut` of `_to` on UniV3
     *
     * @param _from Address of token to swap from
     * @param _to Address of token to swap to
     * @param _amountOut Exact amount of `_to` to receive
     * @param _fee UniV3 pool fee
     */
    function _swap(
        address _from,
        address _to,
        uint256 _amountOut,
        uint24 _fee
    ) internal {
        uniRouter.exactOutputSingle(
            uniV3Router.ExactOutputSingleParams(
                _from,
                _to,
                _fee,
                address(this),
                _amountOut,
                type(uint256).max,
                0
            )
        );
    }

    /**
     * Quote an exact input swap on UniV3
     *
     * @param _from Token to swap from
     * @param _to Token to swap to
     * @param _amountOut Exact amount of `_to` tokens to be received for `_amountIn` `_from` tokens
     * @return _amountIn Amount to send in order to receive `_amountOut` `to` tokens
     */
    function _quoteExactOutput(
        address _from,
        address _to,
        uint256 _amountOut,
        uint24 _fee
    ) internal returns (uint256 _amountIn) {
        try oracle.quoteExactOutputSingle(_from, _to, _fee, _amountOut, 0) returns (uint256 _p) {
            _amountIn = _p;
        } catch {
            _amountIn = type(uint256).max;
        }
    }

    /**
     * Get the lending logic of a wrapped token
     *
     * @param _wrapped Address of wrapped token
     * @return ILendingLogic - Lending logic associated with `_wrapped`
     */
    function getLendingLogicFromWrapped(address _wrapped) internal view returns (ILendingLogic) {
        return ILendingLogic(
            lendingRegistry.protocolToLogic(
                lendingRegistry.wrappedToProtocol(
                    _wrapped
                )
            )
        );
    }

    /**
     * Yoinked from the geniuses behind solmate
     * https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol
     *
     * (x*y)/z
     */
    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
        // Store x * y in z for now.
            z := mul(x, y)

        // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

        // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    // -------------------------------
    // ADMIN FUNCTIONS
    // -------------------------------

    /**
     * Update the Uni V3 Router
     *
     * @param _newRouter New Uni V3 Router address
     */
    function updateUniRouter(address _newRouter, address _oracle) external onlyOwner {
        // Update stored Uni V3 exchange
        uniRouter = uniV3Router(_newRouter);

        // Re-approve WETH
        WETH.approve(_newRouter, 0);
        WETH.approve(_newRouter, type(uint256).max);

        // Re-approve USDC
        USDC.approve(_newRouter, 0);
        USDC.approve(_newRouter, type(uint256).max);
    }

    /**
     * Update the Uni V3 Oracle
     *
     * @param _newOracle New Uni V3 Oracle address
     */
    function updateUniOracle(address _newOracle) external onlyOwner {
        oracle = uniOracle(_newOracle);
    }

    receive() external payable {}
}
