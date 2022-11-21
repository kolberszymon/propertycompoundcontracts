// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IGameBridge {
  function buyGame(address _buyer, address _game) external payable;
}
