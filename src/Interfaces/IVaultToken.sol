// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

interface IVaultToken {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    function convertToAssets(uint256 shares) external view returns (uint256);
}