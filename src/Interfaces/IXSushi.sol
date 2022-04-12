// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;

pragma solidity ^0.7.1;

import "@openzeppelin/token/ERC20/IERC20.sol";

interface IXSushi is IERC20 {
    function enter(uint256 _amount) external;
    function leave(uint256 _share) external;
}
