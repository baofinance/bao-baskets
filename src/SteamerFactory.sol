// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/access/Ownable.sol";
import "./Steamer.sol";

contract SteamerFactoryContract is Ownable {
    event SteamerCreated(
        address Steamer,
        address Pie,
        address Recipe
    );
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address[] public steamers;
    mapping(address => bool) public isSteamer;

    function CreateSteamer(address _pie, address _recipe, uint256 _maxSteam, uint256 _minDeposit) public onlyOwner returns(Steamer){

        Steamer steamer = new Steamer(_pie, _recipe, weth, _maxSteam, _minDeposit);
        steamer.transferOwnership(owner());
        steamers.push(address(steamer));
        isSteamer[address(steamer)] = true;

        emit SteamerCreated(address(steamer), _pie, _recipe);
        return(steamer);
    }
}
