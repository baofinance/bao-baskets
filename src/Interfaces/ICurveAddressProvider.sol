pragma solidity ^0.7.0;

interface ICurveAddressProvider {
    function get_address(uint256 id) external view returns (address);

    function get_registry() external view returns (address);
}