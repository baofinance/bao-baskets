// File: localhost/src/Registry.sol

pragma solidity ^0.7.0;

import "@openzeppelin/access/Ownable.sol";

contract BasketRegistry is Ownable {
    mapping(address => bool) public inRegistry;
    address[] public entries;

    function addBasket(address _basket) external onlyOwner {
        require(!inRegistry[_basket], "Basket is already in Registry");
        entries.push(_basket);
        inRegistry[_basket] = true;
    }

    function removeBasket(uint256 _index) public onlyOwner {
        address registryAddress = entries[_index];

        inRegistry[registryAddress] = false;

        // Move last to index location
        entries[_index] = entries[entries.length - 1];
        // Pop last one off
        entries.pop();
    }

    function removeBasketByAddress(address _address) external onlyOwner {
        // Search for pool and remove it if found. Otherwise do nothing
        for(uint256 i = 0; i < entries.length; i ++) {
            if(_address == entries[i]) {
                removeBasket(i);
                break;
            }
        }
    }
}
