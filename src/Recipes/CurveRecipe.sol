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

pragma experimental ABIEncoderV2;

/**
 * CurveRecipe contract for BaoFinance's Baskets Protocol (PieDAO fork)
 *
 * TODO:
 * - [x] Initial curve exchange integration
 * - [ ] Accept ETH by swapping to USDC before Curve interactions.
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
    ILendingRegistry immutable lendingRegistry;
    IPieRegistry immutable pieRegistry;
    ICurveAddressProvider immutable curveAddressProvider;

    // -------------------------------
    // VARIABLES
    // -------------------------------

    ICurveExchange curveExchange;

    /**
     * Create a new CurveRecipe.
     *
     * @param _usdc USDC address
     * @param _lendingRegistry LendingRegistry address
     * @param _pieRegistry PieRegistry address
     * @param _curveAddressProvider Curve Address Provider address
     */
    constructor(
        address _usdc,
        address _lendingRegistry,
        address _pieRegistry,
        address _curveAddressProvider
    ) {
        require(_usdc != address(0), "USDC_ZERO");
        require(_lendingRegistry != address(0), "LENDING_MANAGER_ZERO");
        require(_pieRegistry != address(0), "PIE_REGISTRY_ZERO");

        USDC = IERC20(_usdc);
        lendingRegistry = ILendingRegistry(_lendingRegistry);
        pieRegistry = IPieRegistry(_pieRegistry);

        curveAddressProvider = ICurveAddressProvider(_curveAddressProvider);
        // Can't read from immutable variables in the constructor, so we
        // re-instantiate the address provider inline
        curveExchange = ICurveExchange(ICurveAddressProvider(_curveAddressProvider).get_address(2));
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
        USDC.safeTransferFrom(_msgSender(), address(this), _maxInput);

        outputAmount = _bake(_outputToken, _mintAmount);

        uint256 remainingInputBalance = USDC.balanceOf(address(this));
        if (remainingInputBalance > 0) {
            USDC.transfer(_msgSender(), remainingInputBalance);
        }

        IERC20(_outputToken).safeTransfer(_msgSender(), outputAmount);

        return (inputAmountUsed, outputAmount);
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
     * @param _mintAmount Amount of basket tokens to mint
     * @return outputAmount Amount of basket tokens minted
     */
    function _bake(address _outputToken, uint256 _mintAmount) internal returns (uint256 outputAmount) {
        require(pieRegistry.inRegistry(_outputToken));

        swapForUnderlying(_outputToken, _mintAmount);

        outputAmount = IERC20(_outputToken).balanceOf(address(this));
    }

    /**
     * Swap for the underlying assets of a pie using only Curve. The source token will always be USDC.
     *
     * @param _basket Basket to pull underlying assets from
     * @param _outputAmount Amount of basket tokens to mint
     */
    function swapForUnderlying(address _basket, uint256 _outputAmount) internal {
        IPie basket = IPie(_basket);
        (address[] memory tokens, uint256[] memory amounts) = basket.calcTokensForAmount(_outputAmount);

        // Load USDC address into memory to prevent multiple SLOADs in the loop
        address _usdc = address(USDC);
        // Store re-assignable values, less memory allocation
        address _token;
        uint256 _amount;

        for (uint256 i; i < tokens.length; ++i) {
            _token = tokens[i];
            _amount = amounts[i];

            (address _pool, uint256 _out) = curveExchange.get_best_rate(_usdc, _token, _amount);
            curveExchange.exchange(
                _pool,
                _usdc,
                _token,
                _amount,
                _out
            );

            IERC20 token = IERC20(_token);
            token.approve(_basket, 0);
            token.approve(_basket, _amount);
            require(amounts[i] <= token.balanceOf(address(this)), "We are trying to deposit more then we have");
        }
        basket.joinPool(_outputAmount);
    }

    // -------------------------------
    // ADMIN FUNCTIONS
    // -------------------------------

    /**
     * Update the curve exchange to the current value stored in Curve's Address Provider
     */
    function updateCurveExchange() external onlyOwner {
        curveExchange = ICurveExchange(curveAddressProvider.get_address(2));
    }
}
