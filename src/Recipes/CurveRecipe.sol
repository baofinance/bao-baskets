// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../Interfaces/ILendingRegistry.sol";
import "../Interfaces/ILendingLogic.sol";
import "../Interfaces/IPieRegistry.sol";
import "../Interfaces/IPie.sol";
import "../Interfaces/ICurveExchange.sol";
import "../Interfaces/ICurveAddressProvider.sol";
import "@openzeppelin/token/ERC20/SafeERC20.sol";
import "@openzeppelin/math/SafeMath.sol";
import "@openzeppelin/access/Ownable.sol";
import "../Interfaces/IUniV3Router.sol";
import "../Interfaces/IWETH.sol";

pragma experimental ABIEncoderV2;

/**
 * CurveRecipe contract for BaoFinance's Baskets Protocol (PieDAO fork)
 *
 * TODO:
 * - [x] Initial curve exchange integration
 * - [x] Accept ETH by swapping to USDC before Curve interactions.
 * - [ ] Optimize where possible
 * - [ ] Incorporate into test suite for bSTBL
 *
 * @author vex
 */
contract CurveRecipe is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // -------------------------------
    // CONSTANTS
    // -------------------------------

    IERC20 immutable USDC;
    IWETH immutable WETH;
    ILendingRegistry immutable lendingRegistry;
    IPieRegistry immutable pieRegistry;
    ICurveAddressProvider immutable curveAddressProvider;

    // -------------------------------
    // VARIABLES
    // -------------------------------

    ICurveExchange curveExchange;
    uniV3Router uniRouter;

    /**
     * Create a new CurveRecipe.
     *
     * @param _usdc USDC address
     * @param _weth WETH address
     * @param _lendingRegistry LendingRegistry address
     * @param _pieRegistry PieRegistry address
     * @param _curveAddressProvider Curve Address Provider address
     * @param _uniV3Router Uniswap V3 Router address
     */
    constructor(
        address _usdc,
        address _weth,
        address _lendingRegistry,
        address _pieRegistry,
        address _curveAddressProvider,
        address _uniV3Router
    ) {
        require(_usdc != address(0), "USDC_ZERO");
        require(_lendingRegistry != address(0), "LENDING_MANAGER_ZERO");
        require(_pieRegistry != address(0), "PIE_REGISTRY_ZERO");

        USDC = IERC20(_usdc);
        WETH = IWETH(_weth);
        lendingRegistry = ILendingRegistry(_lendingRegistry);
        pieRegistry = IPieRegistry(_pieRegistry);

        curveAddressProvider = ICurveAddressProvider(_curveAddressProvider);
        curveExchange = ICurveExchange(ICurveAddressProvider(_curveAddressProvider).get_address(2));

        uniRouter = uniV3Router(_uniV3Router);

        // Approve max USDC spending on Curve Exchange
        IERC20(_usdc).approve(address(curveExchange), type(uint256).max);
        // Approve max WETH spending on Uni Router
        IWETH(_weth).approve(address(uniRouter), type(uint256).max);
    }

    // -------------------------------
    // PUBLIC FUNCTIONS
    // -------------------------------

    /**
     * External bake function.
     * Mints _mintAmount basket tokens with as little of _maxInput as possible.
     *
     * @param _outputToken Basket token to mint
     * @param _maxInput Max USDC to use to mint _mintAmount basket tokens
     * @param _mintAmount Target amount of basket tokens to mint
     * @return inputAmountUsed Amount of USDC used to mint the basket token
     * @return outputAmount Amount of basket tokens minted
     */
    function bake(
        address _outputToken,
        uint256 _maxInput,
        uint256 _mintAmount
    ) external returns (uint256 inputAmountUsed, uint256 outputAmount) {
        // Transfer USDC to the Recipe
        USDC.safeTransferFrom(msg.sender, address(this), _maxInput);

        // Bake _mintAmount basket tokens
        outputAmount = _bake(_outputToken, _mintAmount);

        // Transfer remaining USDC to msg.sender
        uint256 remainingInputBalance = USDC.balanceOf(address(this));
        if (remainingInputBalance > 0) {
            USDC.transfer(msg.sender, remainingInputBalance);
        }
        inputAmountUsed = _maxInput - remainingInputBalance;

        // Transfer minted basket tokens to msg.sender
        IERC20(_outputToken).safeTransfer(msg.sender, outputAmount);
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
        uniV3Router.ExactInputSingleParams memory params = uniV3Router.ExactInputSingleParams({
            tokenIn : address(WETH),
            tokenOut : address(USDC),
            fee : 3000,
            recipient : address(this),
            deadline : block.timestamp,
            amountIn : WETH.balanceOf(address(this)),
            amountOutMinimum : 0,
            sqrtPriceLimitX96 : 0
        });

        // Transfer WETH for USDC on UniV3
        uniRouter.exactInputSingle(params);

        // Bake basket
        uint256 outputAmount = _bake(_basket, _mintAmount);
        // Transfer minted baskets to msg.sender
        IERC20(_basket).safeTransfer(msg.sender, outputAmount);

        // Send remaining USDC to msg.sender
        uint256 usdcBalance = USDC.balanceOf(address(this));
        if (usdcBalance != 0) {
            USDC.safeTransfer(msg.sender, usdcBalance);
        }
    }

    // -------------------------------
    // INTERNAL FUNCTIONS
    // -------------------------------

    /**
     * Internal bake function.
     * Checks if _outputToken is a valid basket, mints _mintAmount basketTokens, and returns the real
     * amount minted.
     *
     * @param _outputToken Basket token to bake
     * @param _mintAmount Target amount of basket tokens to mint
     * @return outputAmount Amount of basket tokens minted
     */
    function _bake(address _outputToken, uint256 _mintAmount) internal returns (uint256 outputAmount) {
        require(pieRegistry.inRegistry(_outputToken));

        swapAndJoin(_outputToken, _mintAmount);

        outputAmount = IERC20(_outputToken).balanceOf(address(this));
    }

    /**
     * Swap for the underlying assets of a basket using only Curve and mint _outputAmount basket tokens.
     *
     * @param _basket Basket to pull underlying assets from
     * @param _mintAmount Target amount of basket tokens to mint
     */
    function swapAndJoin(address _basket, uint256 _mintAmount) internal {
        IPie basket = IPie(_basket);
        (address[] memory tokens, uint256[] memory amounts) = basket.calcTokensForAmount(_mintAmount);

        // Load USDC address into memory to prevent multiple SLOADs in the loop
        address _usdc = address(USDC);
        // Store re-assignable values, less memory allocation
        address _token;
        uint256 _amount;

        for (uint256 i; i < tokens.length; ++i) {
            _token = tokens[i];
            _amount = amounts[i];

            // If the token is registered in the lending registry, swap to
            // its underlying token and lend it.
            address underlying = lendingRegistry.wrappedToUnderlying(_token);
            if (underlying != address(0)) {
                // Get underlying amount according to the exchange rate
                ILendingLogic lendingLogic = getLendingLogicFromWrapped(_token);
                uint256 underlyingAmount = _amount.mul(lendingLogic.exchangeRate(_token)).div(1e18).add(1);

                // Swap for the underlying asset on Curve
                _swapCurve(_usdc, underlying, underlyingAmount);

                // Execute lending transactions
                (address[] memory targets, bytes[] memory data) = lendingLogic.lend(underlying, underlyingAmount, address(this));
                for (uint256 j; j < targets.length; ++j) {
                    (bool success,) = targets[j].call{value : 0}(data[j]);
                    require(success, "CALL_FAILED");
                }
            } else {
                _swapCurve(_usdc, _token, _amount);
            }

            IERC20 token = IERC20(_token);
            token.approve(_basket, 0);
            token.approve(_basket, _amount);
            require(amounts[i] <= token.balanceOf(address(this)), "SLIPPAGE_THRESHOLD_EXCEEDED");
        }
        basket.joinPool(_mintAmount);
    }

    function _swapCurve(
        address _usdc,
        address _token,
        uint256 _amount
    ) internal {
        (address _pool, uint256 _out) = curveExchange.get_best_rate(
            _usdc,
            _token,
            _amount
        );
        curveExchange.exchange(
            _pool,
            _usdc,
            _token,
            _amount,
            _out
        );
    }

    function getLendingLogicFromWrapped(address _wrapped) internal view returns (ILendingLogic) {
        return ILendingLogic(
            lendingRegistry.protocolToLogic(
                lendingRegistry.wrappedToProtocol(
                    _wrapped
                )
            )
        );
    }

    // -------------------------------
    // ADMIN FUNCTIONS
    // -------------------------------

    /**
     * Update the curve exchange to the current value stored in Curve's Address Provider
     */
    function updateCurveExchange() external onlyOwner {
        address _exchange = curveAddressProvider.get_address(2);

        // Update stored Curve exchange
        curveExchange = ICurveExchange(_exchange);

        // Re-approve USDC
        USDC.approve(_exchange, 0);
        USDC.approve(_exchange, type(uint256).max);
    }

    /**
     * Update the Uni V3 Router
     *
     * @param _newRouter New Uni V3 Router address
     */
    function updateUniRouter(address _newRouter) external onlyOwner {
        // Update stored Curve exchange
        uniRouter = uniV3Router(_newRouter);

        // Re-approve USDC
        WETH.approve(_newRouter, 0);
        WETH.approve(_newRouter, type(uint256).max);
    }

    receive() external payable {}
}
