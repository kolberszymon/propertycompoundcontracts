// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
  constructor() ERC20("USDT", "USDT") {}

  function mint(address _to, uint256 _number) external {
    _mint(_to, 10**6 * _number);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}
