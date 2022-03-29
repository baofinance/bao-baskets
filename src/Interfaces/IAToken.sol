// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

interface IAToken {
    function redeem(uint256 _amount) external;
}