// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PBorrow is ERC20, Ownable {
  uint256 private interestRatePercentage = 20;
  address private defiProtocol;

  // Initial supply of pToken is 0
  constructor(address _defiProtocol) ERC20("pToken", "PT") Ownable() {
    defiProtocol = _defiProtocol;
  }

  function borrow(address _to, uint256 _amount) external onlyOwner {
    // Minting pBorrow tokens that are 1:1 with stablecoins
    _mint(_to, _amount);

    // Minting additional interestRate tokens, which goes to the pool
    _mint(defiProtocol, (_amount * interestRatePercentage) / 100);
  }

  function repay(uint256 _amount) external {
    _burn(msg.sender, _amount);
  }

  function getInterestRate() public view returns (uint256) {
    return interestRatePercentage;
  }
}
