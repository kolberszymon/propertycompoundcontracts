// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./IGameBridge.sol";

contract Game1Bridge is IGameBridge {
  // It will be referral count contract address because we'll destroy the contract when the game is deleted to retrieve gas
  address private immutable owner;

  constructor() {
    owner = msg.sender;
  }

  function buyGame(address _buyer, address _game) external payable {
    (bool success, ) = _game.call{ value: msg.value }(
      abi.encodeWithSignature("buyGameInMyFancyGame(address)", _buyer)
    );

    require(success, "something went wrong");
  }

  function deleteGame() external {
    require(msg.sender == owner, "Only owner can delete the game");
    selfdestruct(payable(owner));
  }
}
