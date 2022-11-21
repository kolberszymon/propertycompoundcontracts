// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Game1 is ERC721 {
  using SafeMath for uint256;

  uint256 public gamePrice = 0.1 * 10**18;
  uint256 private tokenId = 1;

  constructor() ERC721("GAME1", "G1") {}

  function buyGameInMyFancyGame(address _buyer) external payable {
    _safeMint(_buyer, tokenId);
    tokenId.add(1);
  }
}
