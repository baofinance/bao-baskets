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
import "../../lib/forge-std/src/Test.sol";
import "../Interfaces/ICurveRegistry.sol";
import "../Interfaces/ICurveCalculator.sol";

pragma experimental ABIEncoderV2;

/**
 * CurveRecipe contract for BaoFinance's Baskets Protocol (PieDAO fork)
 *
 * NOTE: This is broken. Curve's get_dx function does not return
 * input for *exact* output, and it also does not work with
 * non-stable pools.
 *
 * TODO:
 * - [x] Initial curve exchange integration
 * - [x] Accept ETH by swapping to USDC before Curve interactions.
 * - [ ] Get `getDx` working with the RAI pool
 * - [ ] Optimize where possible (add mulDiv, etc.)
 * - [x] Incorporate into test suite for bSTBL
 *
 * @author vex
 */
contract CurveRecipe is Ownable, Test {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // -------------------------------
    // CONSTANTS
    // -------------------------------

    address constant RAI_3POOL = 0x618788357D0EBd8A37e763ADab3bc575D54c2C7d;
    address constant _3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    ICurveCalculator constant curveCalculator = ICurveCalculator(0xc1DB00a8E5Ef7bfa476395cdbcc98235477cDE4E);

    IERC20 immutable USDC;
    IWETH immutable WETH;
    ILendingRegistry immutable lendingRegistry;
    IPieRegistry immutable basketRegistry;
    ICurveAddressProvider immutable curveAddressProvider;

    // -------------------------------
    // VARIABLES
    // -------------------------------

    ICurveRegistry curveRegistry;
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
        basketRegistry = IPieRegistry(_pieRegistry);

        curveAddressProvider = ICurveAddressProvider(_curveAddressProvider);
        curveExchange = ICurveExchange(ICurveAddressProvider(_curveAddressProvider).get_address(2));
        curveRegistry = ICurveRegistry(ICurveAddressProvider(_curveAddressProvider).get_registry());

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

    /**
     * Get the price of `_amount` basket tokens in USDC
     *
     * @param _basket Basket token to get the price of
     * @param _amount Amount of basket tokens to get price of
     * @return _price Price of `_amount` basket tokens in USDC
     */
    function getPrice(address _basket, uint256 _amount) external view returns (uint256 _price) {
        // Check that _basket is a valid basket
        require(basketRegistry.inRegistry(_basket));

        // Loop through all the tokens in the basket and get their prices on Curve
        (address[] memory tokens, uint256[] memory amounts) = IPie(_basket).calcTokensForAmount(_amount);
        address _usdc = address(USDC);
        address _token;
        address _underlying;
        uint256 _amount;
        for (uint256 i; i < tokens.length; ++i) {
            _token = tokens[i];
            _amount = amounts[i];

            require(_amount != 0, "MINT_AMOUNT_INVALID");

            _underlying = lendingRegistry.wrappedToUnderlying(_token);
            if (_underlying != address(0)) {
                // TODO: Replace with a more efficient mulDiv function
                _amount = _amount.mul(
                    getLendingLogicFromWrapped(_token).exchangeRateView(_token)
                ).div(1e18);
                _token = _underlying;
            }

            // If the token is USDC, we don't need to perform a swap before lending.
            _price += _token == _usdc ? _amount : getDx(_usdc, _token, _amount);
        }
        return _price;
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
        require(basketRegistry.inRegistry(_outputToken));

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
                uint256 underlyingAmount;

                emit log("---------------------------");
                emit log_named_address("Token to swap", underlying);

                // Swap for the underlying asset on Curve
                if (underlying == _usdc) {
                    // If the asset is already USDC, there is no need to swap
                    underlyingAmount = _amount.mul(lendingLogic.exchangeRate(_token)).div(1e18);
                    emit log("No swap necessary. Lending USDC");
                } else {
                    emit log_named_uint("Desired Amount", _amount.mul(lendingLogic.exchangeRate(_token)).div(1e18));
                    uint256 dx = getDx(_usdc, underlying, _amount.mul(lendingLogic.exchangeRate(_token)).div(1e18));
                    underlyingAmount = _swapCurve(_usdc, underlying, dx);
                    emit log_named_uint("Received Amount", IERC20(underlying).balanceOf(address(this)));
                }

                // Execute lending transactions
                (address[] memory targets, bytes[] memory data) = lendingLogic.lend(underlying, underlyingAmount, address(this));
                for (uint256 j; j < targets.length; ++j) {
                    (bool success,) = targets[j].call{value : 0}(data[j]);
                    require(success, "CALL_FAILED");
                }

                emit log_named_address("Lending Token", _token);
                emit log_named_uint("Underlying Balance Remaining", IERC20(underlying).balanceOf(address(this)));
                emit log_named_uint("Lent Balance", IERC20(_token).balanceOf(address(this)));
            } else {
                _swapCurve(_usdc, _token, _amount);
            }

            IERC20 token = IERC20(_token);
            token.approve(_basket, 0);
            token.approve(_basket, _amount);
            emit log_named_uint("Amount required (0.25% slippage allowed)", amounts[i]);

            // TODO: Add 0.25% slippage tolerance.
            require(amounts[i] <= token.balanceOf(address(this)) * 10025 / 10000, "SLIPPAGE_THRESHOLD_EXCEEDED");
            // require(amounts[i] <= token.balanceOf(address(this)), "SLIPPAGE_THRESHOLD_EXCEEDED");
        }
        basket.joinPool(_mintAmount);
    }

    /**
     * Swap from _from to _to on Curve Exchange
     *
     * @param _from Asset to swap from
     * @param _to Asset to swap to
     * @param _amount Amount of _from to swap
     */
    function _swapCurve(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (uint256 _output) {
        address _pool = getPreferredPool(_to);
        uint256 _out = curveExchange.get_exchange_amount(
            _pool,
            _from,
            _to,
            _amount
        );

        emit log_named_address("Pool", _pool);
        emit log_named_uint("Amount In (dx)", _amount);
        emit log_named_uint("Expected Out", _out);

        _output = curveExchange.exchange(
            _pool,
            _from,
            _to,
            _amount,
            _out
        );
    }

    /**
     * Get the amount received when swapping _from for _to on Curve Exchange
     *
     * @param _from Asset to swap from
     * @param _to Asset to swap to
     * @param _amount Amount of _to to be received
     * @return _dx Amount of _from to be sent in order to receive _amount of _to
     */
    function getDx(
        address _from,
        address _to,
        uint256 _amount
    ) internal view returns (uint256 _dx) {
        address _pool = getPreferredPool(_to);
        uint256[8] memory balances;
        uint256[8] memory rates;
        uint256[8] memory decimals;
        (int128 i, int128 j, bool is_underlying) = curveRegistry.get_coin_indices(_pool, _from, _to);
        uint256 n_coins = curveRegistry.get_n_coins(_pool)[uint256(is_underlying ? 1 : 0)];

        uint256 amountCopy = _amount; // Copy _amount higher in the stack to prevent stack too deep error

        if (is_underlying) {
            balances = curveRegistry.get_underlying_balances(_pool);
            decimals = curveRegistry.get_underlying_decimals(_pool);
            for (uint256 x; x < 8; ++x) {
                if (x == n_coins) {
                    break;
                }
                rates[x] = 1e18;
            }
        } else {
            balances = curveRegistry.get_balances(_pool);
            decimals = curveRegistry.get_decimals(_pool);
            rates = curveRegistry.get_rates(_pool);
        }

        for (uint256 x; x < 8; ++x) {
            if (x == n_coins) {
                break;
            }
            decimals[x] = 10 ** (18 - decimals[x]);
        }

        _dx = curveCalculator.get_dx(
            int128(n_coins),
            balances,
            curveRegistry.get_A(_pool),
            curveRegistry.get_fees(_pool)[0],
            rates,
            decimals,
            is_underlying,
            i,
            j,
            amountCopy
        );
    }

    /**
     * Get the lending logic of a wrapped token
     *
     * @param _wrapped Address of wrapped token
     * @return ILendingLogic - Lending logic associated with _wrapped
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
     * Get the preferred pool for swapping to `_to` from USDC on Curve.
     * We hard-code the preferred pools to ensure that the intended
     * pools are used. With `get_best_rate`, `getDx` and `_swapCurve`
     * may get different results, resulting in different expectations.
     *
     * @param _to Token to swap to
     * @return address - Address of pool to use
     */
    function getPreferredPool(address _to) internal view returns (address) {
        // If token is RAI, use RAI-3Pool. Else, use 3Pool.
        return _to == 0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919 ? RAI_3POOL : _3POOL;
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
        curveRegistry = ICurveRegistry(curveAddressProvider.get_registry());

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
