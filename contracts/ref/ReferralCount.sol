// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IGameBridge.sol";
import "hardhat/console.sol";

contract ReferralCount is Ownable {
  struct Referral {
    uint256 refCount;
    uint256 fee;
    address bridgeAddress; // Bride address for
    address gameAddress;
  }

  struct Game {
    uint256 price;
    address contractAddress;
  }

  event AddGame(address indexed contractAddress);
  event AddReferral(address indexed gameAddress);

  // Game (NFT Contract) address to referrals
  mapping(address => Referral) referrals;
  // Commision should be probably dynamic in accordance to different games,
  // because there can be different deals
  uint256 private commision = 20; // in %
  uint256 private unpaidReferralLimit = 50; // how many referals can be unpaid

  Game[] private games;

  constructor() Ownable() {}

  function buyGame(address _game) external payable {
    // 1. We can't use delegate call here, because we don't want to write into ReferralCount contract

    Referral memory referral = referrals[_game];
    (bool gameExist, uint256 gamePrice) = getGamePrice(_game);

    require(
      referral.refCount <= unpaidReferralLimit,
      "You can't buy this game right now"
    );
    require(gameExist, "Game does not exist ;)");
    require(msg.value >= gamePrice, "Value sent is too low");

    referral.refCount += 1;
    referral.fee += (msg.value * commision) / 100;

    referrals[_game] = referral;
    // Invoking buyGame function, and sending funds along
    (bool success, ) = referral.bridgeAddress.call{ value: msg.value }(
      abi.encodeWithSignature("buyGame(address,address)", msg.sender, _game)
    );

    require(success, "something went wrong11");

    emit AddReferral(_game);
  }

  // Pay for gathered referrals
  function payRefferal(address _game) external payable {
    Referral memory referral = referrals[_game];

    // Check if the value is enough to cover all referal
    require(msg.value >= referral.fee, "Value is too low");

    referral.refCount = 0;
    referral.fee = 0;

    referrals[_game] = referral;
  }

  function addGame(
    address _bridgeAddress,
    address _game,
    uint256 _price
  ) external onlyOwner {
    games.push(Game(_price, _game));
    referrals[_game] = Referral(0, 0, _bridgeAddress, _game);

    emit AddGame(_game);
  }

  function deleteGame(address _game) external onlyOwner {
    Referral memory referral = referrals[_game];

    require(
      referral.refCount == 0 && referral.fee == 0,
      "In order to delete a game it needs to pay back all of it's due"
    );

    delete referrals[_game];
    removeGameFromArray(_game);
  }

  function removeGameFromArray(address _game) internal {
    (bool gameExist, uint256 index) = getGamePrice(_game);
    require(gameExist, "Game does not exist ;)");

    games[index] = games[games.length - 1];
    games.pop();
  }

  function getGameIndex(address _game) internal view returns (bool, uint256) {
    for (uint256 i = 0; i < games.length; i++) {
      if (games[i].contractAddress == _game) {
        return (true, i);
      }
    }

    return (false, 0);
  }

  function getGamePrice(address _game) internal view returns (bool, uint256) {
    for (uint256 i = 0; i < games.length; i++) {
      if (games[i].contractAddress == _game) {
        return (true, games[i].price);
      }
    }

    return (false, 0);
  }

  function setCommision(uint256 _commision) external onlyOwner {
    commision = _commision;
  }

  function setUnpaidReferralLimit(uint256 _limit) external onlyOwner {
    unpaidReferralLimit = _limit;
  }

  function getCommision() external view returns (uint256) {
    return commision;
  }

  function getReferral(address _game) external view returns (Referral memory) {
    return referrals[_game];
  }
}
