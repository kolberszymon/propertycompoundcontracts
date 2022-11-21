// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./ERC20DeFi.sol";
import "hardhat/console.sol";

error DeFiProtocol__NotEnoughQuantity();
error DeFiProtocol__TokenNotSupported();
error DeFiProtocol__NotSufficientBalance();
error DeFiProtocol__TransferFromFailure();
error DeFiProtocol__StakingStillLocked();

// Change to be clean loan

contract DeFi is Ownable {
  struct Staker {
    address staker;
    uint256 amount;
    address stakedToken;
    uint256 startDate;
    uint256 duration;
    uint256 stakingRate;
  }

  // Let's just calculate it when the person wants to pay back
  // if he wants to pay back before the end it just calculate

  struct Borrower {
    address borrower;
    uint256 amount;
    uint256 startDate;
    uint256 duration;
    uint256 lendingRate;
    uint256 amountRepaid;
    bool repaid;
  }

  ERC20DeFi public immutable pLend;
  ERC20DeFi public immutable pBorrow;

  uint256 private stakingRate = 16;
  uint256 private lendingRate = 20;

  mapping(address => bool) public isTokenAllowed;
  mapping(address => Staker[]) public staking;
  mapping(address => Borrower[]) public borrowing;

  address[] allowedTokens;

  event Stake(
    address indexed stakerAddress,
    uint256 amount,
    address stakedToken,
    uint256 startDate
  );
  event Redeem();
  event Borrow();

  // Modifier to check token allowance
  modifier checkAllowance(uint256 amount, address token) {
    IERC20 _token = IERC20(token);
    require(
      _token.allowance(msg.sender, address(this)) >= amount,
      "Not enough allowance"
    );
    _;
  }

  modifier checkIfTokenIsAllowed(address token) {
    require(isTokenAllowed[token], "Token not allowed");
    _;
  }

  constructor() Ownable() {
    pLend = new ERC20DeFi("pLend", "pL");
    pBorrow = new ERC20DeFi("pBorrow", "pB");
  }

  /**
      STAKING PART
   */

  function stake(uint256 _amount, address _token)
    external
    checkIfTokenIsAllowed(_token)
    checkAllowance(_amount, _token)
  {
    address from = msg.sender;

    if (_amount <= 0) {
      revert DeFiProtocol__NotEnoughQuantity();
    }

    // It has to be approved earlier
    bool success = IERC20(_token).transferFrom(from, address(this), _amount);

    // If transferFrom failed, revert
    if (!success) {
      revert DeFiProtocol__TransferFromFailure();
    }

    staking[from].push(
      Staker(from, _amount, _token, block.timestamp, 365, stakingRate)
    );

    emit Stake(from, _amount, _token, block.timestamp);
  }

  function redeemStake(uint256 _index) public {
    Staker memory staker = staking[msg.sender][_index];

    // If the staking is still locked, revert
    require(
      block.timestamp >= staker.startDate + staker.duration * 1 days,
      "Staking is still locked"
    );

    // Deleting from Staker account
    delete staking[msg.sender][_index];

    // Reddeming token
    pLend.mint(
      staker.staker,
      (staker.amount * (100 + staker.stakingRate)) / 100
    );

    emit Redeem();
  }

  function exchangeLendingTokens(address _redeemToken, uint256 _amount)
    external
    checkAllowance(_amount, address(pLend))
  {
    if (_amount <= 0) {
      revert DeFiProtocol__NotEnoughQuantity();
    }

    // User send pLend token that are 1:1 exchangeble
    bool success = IERC20(pLend).transferFrom(
      msg.sender,
      address(this),
      _amount
    );

    if (!success) {
      revert DeFiProtocol__TransferFromFailure();
    }

    // Contract transfer to user stable coin
    IERC20(_redeemToken).transfer(msg.sender, _amount);

    // Burning received pLend tokens
    pLend.burn(_amount);
  }

  /**
      BORROWING PART
   */

  function borrow(uint256 _amount, address _borrower) public onlyOwner {
    if (_amount <= 0) {
      revert DeFiProtocol__NotEnoughQuantity();
    }

    // Adding borrower to an array
    borrowing[_borrower].push(
      Borrower(_borrower, _amount, block.timestamp, 365, lendingRate, 0, false)
    );
    // Minting pBorrow tokens to _borrower address
    pBorrow.mint(_borrower, _amount);

    emit Borrow();
  }

  // How should he be able to repay that?
  // amountRepaid - amount that already have been repaid
  // we need to calculate amount that needs to be repaid

  function repay(uint256 _index) external {
    Borrower memory borrower = borrowing[msg.sender][_index];
  }

  /**
    MAINTANANCE PART
   */

  function removeFromArray(address _token) internal {
    address[] memory _allowedTokens = allowedTokens;

    for (uint256 i = 0; i < _allowedTokens.length - 1; i++) {
      if (_allowedTokens[i] == _token) {
        _allowedTokens[i] = _allowedTokens[_allowedTokens.length - 1];
        delete _allowedTokens[_allowedTokens.length - 1];
      }
    }

    allowedTokens = _allowedTokens;
  }

  function addAllowedToken(address _token) external onlyOwner {
    require(!isTokenAllowed[_token], "Token is already allowed");
    isTokenAllowed[_token] = true;
    allowedTokens.push(_token);
  }

  function removeAllowedToken(address _token) external onlyOwner {
    require(isTokenAllowed[_token], "Chill... Token is not allowed anyway");
    isTokenAllowed[_token] = false;
    removeFromArray(_token);
  }

  function getBalanceOfLendTokens(address _of) external view returns (uint256) {
    return pLend.balanceOf(_of);
  }
}
