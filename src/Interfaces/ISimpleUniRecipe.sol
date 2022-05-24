pragma solidity 0.7.1;

interface ISimpleUniRecipe {
    function toBasket(address _basket, uint256 _mintAmount) external payable;
}
