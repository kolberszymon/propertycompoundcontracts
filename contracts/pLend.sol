// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PLend is ERC20, Ownable {
  address private _defiProtocol;
  uint256 private lendingInterestPercentage = 15;

  modifier onlyDefiProtocol() {
    require(
      msg.sender == _defiProtocol,
      "Only defi protocol can envoke this function"
    );
    _;
  }

  // Initial supply of pToken is 0
  constructor(address defiProtocol) ERC20("pBorrow", "PB") Ownable() {
    _defiProtocol = defiProtocol;
  }

  function lend(address _to, uint256 _amount) external onlyDefiProtocol {
    _mint(
      _to,
      (_amount * (100 + lendingInterestPercentage)) / lendingInterestPercentage
    );
  }

  function setDefiProtocol(address _to) public onlyOwner {
    _defiProtocol = _to;
  }

  function getDefiProtocol() public view returns (address) {
    return _defiProtocol;
  }
}
