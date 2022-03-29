pragma solidity ^0.8.1;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

interface IWETH is IERC20 {
  function deposit() external payable;
  function transfer(address to, uint value) external returns (bool);
  function withdraw(uint) external;
}
