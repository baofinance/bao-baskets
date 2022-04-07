// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "../Interfaces/IVaultToken";
import "../Interfaces/ILendingLogic.sol";
import "../LendingRegistry.sol";

contract LendingLogic4626 is Ownable, ILendingLogic {

    IVaultToken vaultToken;

    constructor(address _vaultToken) {
        vaultToken = IVaultToken(_vaultToken);
    }

    function getAPRFromWrapped(address _token) public view override returns(uint256) {
        //ToDo:Custom Logic Depending on specific vault implementation
        return(0);
    }

    function getAPRFromUnderlying(address _token) external view override returns(uint256) {
        return(0);
    }

    function lend(address _underlying, uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        IERC20 underlying = IERC20(_underlying);

        targets = new address[](3);
        data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(underlying.approve.selector, vaultToken, 0);

        // Set approval
        targets[1] = _underlying;
        data[1] = abi.encodeWithSelector(underlying.approve.selector, vaultToken, _amount);

        // Deposit into Vault token
        targets[2] = address(vaultToken);
        data[2] =  abi.encodeWithSelector(IVaultToken.deposit.selector, _amount, _tokenHolder);

        return(targets, data);
    }

    function unlend(address _wrapped, uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        targets = new address[](1);
        data = new bytes[](1);

        targets[0] = _wrapped;
        data[0] = abi.encodeWithSelector(IVaultToken.redeem.selector, _amount, _tokenHolder, _tokenHolder);

        return(targets, data);
    }

    function exchangeRate(address _wrapped) external override returns(uint256) {
        return vaultToken.convertToAssets(1e18); 
    }

    function exchangeRateView(address _wrapped) external view override returns(uint256) {
        return vaultToken.convertToAssets(1e18);
    }

}
