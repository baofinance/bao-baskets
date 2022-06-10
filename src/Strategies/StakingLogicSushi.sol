// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import "../LendingRegistry.sol";
import "../Interfaces/IXSushi.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract StakingLogicSushi is ILendingLogic {

    LendingRegistry public lendingRegistry;
    bytes32 public immutable protocolKey;

    constructor(address _lendingRegistry, bytes32 _protocolKey) {
        require(_lendingRegistry != address(0), "INVALID_LENDING_REGISTRY");
        lendingRegistry = LendingRegistry(_lendingRegistry);
        protocolKey = _protocolKey;
    }

    function getAPRFromWrapped(address _token) public view override returns(uint256) {
        return uint256(0);
    }

    function getAPRFromUnderlying(address _token) external view override returns(uint256) {
        return uint256(0);
    }

    function lend(address _underlying,
        uint256 _amount,
        address _tokenHolder
    ) external view override returns(address[] memory targets, bytes[] memory data) {
        IERC20 underlying = IERC20(_underlying);

        targets = new address[](3);
        data = new bytes[](3);

        address SushiBar = lendingRegistry.underlyingToProtocolWrapped(_underlying, protocolKey);

        // zero out approval to be sure
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(underlying.approve.selector, SushiBar, 0);

        // Set approval
        targets[1] = _underlying;
        data[1] = abi.encodeWithSelector(underlying.approve.selector, SushiBar, _amount);

        // Stake in Sushi Bar
        targets[2] = SushiBar;
        data[2] =  abi.encodeWithSelector(IXSushi.enter.selector, _amount);

        return(targets, data);
    }

    function unlend(
        address _wrapped,
        uint256 _amount,
        address _tokenHolder
    ) external view override returns(address[] memory targets, bytes[] memory data) {
        targets = new address[](1);
        data = new bytes[](1);

        targets[0] = _wrapped;
        data[0] = abi.encodeWithSelector(IXSushi.leave.selector, _amount);

        return(targets, data);
    }

    function exchangeRate(address _wrapped) external view override returns(uint256) {
        return _exchangeRate(_wrapped);
    }

    function exchangeRateView(address _wrapped) external view override returns(uint256) {
        return _exchangeRate(_wrapped);
    }

    function _exchangeRate(address _wrapped) internal view returns(uint256) {
        IERC20 xToken = IERC20(_wrapped);
        IERC20 token = IERC20(lendingRegistry.wrappedToUnderlying(_wrapped));
        return mulDivUp(token.balanceOf(_wrapped),10**18,xToken.totalSupply());
    }
     
    //As implemented by big brains of solmate:
    //https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol
    function mulDivUp(
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

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }
} 
