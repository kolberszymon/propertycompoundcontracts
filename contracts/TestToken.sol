// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
  // Initial supply of pToken is 0
  constructor(uint256 _initialAmount) ERC20("testToken", "TT") Ownable() {
    _mint(msg.sender, _initialAmount);
  }
}
