//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

interface IRecipe {
    function bake(
        address _outputToken,
        uint256 _maxInput,
        uint256 _mintAmount,
        uint16[] memory _dexIndex
    ) external returns (uint256 inputAmountUsed, uint256 outputAmount);

    function toPie(address _pie, uint256 _outputAmount, uint16[] memory _dexIndex) external payable;

    function getPricePie(address _pie, uint256 _mintAmount) external returns(uint256 mintPrice, uint16[] memory dexIndex);

    function setUniPoolMapping(address _outputAsset, uint16 _Fee) external;

    function setBalancerPoolMapping(address _inputAsset, bytes32 _pool) external;
}
