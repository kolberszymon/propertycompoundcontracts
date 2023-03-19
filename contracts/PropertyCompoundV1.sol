// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error DeFiProtocol__NotEnoughQuantity();
error DeFiProtocol__TokenNotSupported();
error DeFiProtocol__NotSufficientBalance();
error DeFiProtocol__TransferFromFailure();
error DeFiProtocol__StakingStillLocked();

contract PropertyCompoundV1 is Ownable {
  using SafeMath for uint256;

  event Stake(
    address indexed stakerAddress,
    uint256 amount,
    address stakedToken,
    uint256 startDate
  );

  event Redeem(address indexed stakerAddress, uint256 indexed investmentIndex);

  struct Investment {
    address staker;
    uint256 amount;
    address stakedToken;
    uint256 startDate;
    uint256 duration;
    uint256 yield;
    uint256 paidBack;
    uint256 index;
  }

  struct Loan {
    address borrower;
    uint256 amount;
    uint256 startDate;
    uint256 duration;
    uint256 interestRate;
    uint256 amountRepaid;
    address borrowedToken;
    bool started;
    uint256 index;
  }

  struct AvailableInvestment {
    address tokenAddress;
    uint256 duration;
    uint256 yield;
  }

  mapping(address => Investment[]) public investments;
  mapping(address => Loan[]) public loans;

  AvailableInvestment public availableInvestment;
  uint256 public currentYield;

  /**
    MODIFIERS
  */

  modifier checkAllowance(uint256 amount, address token) {
    IERC20 _token = IERC20(token);
    require(
      _token.allowance(msg.sender, address(this)) >= amount,
      "Not enough allowance"
    );
    _;
  }

  modifier checkIfInvestmentExist() {
    require(
      availableInvestment.tokenAddress != address(0),
      "Investment has not been set"
    );
    _;
  }

  constructor() Ownable() {}

  /**
    STAKING PART
  */

  function stake(uint256 _amount)
    external
    checkIfInvestmentExist
    checkAllowance(_amount, availableInvestment.tokenAddress)
  {
    address from = msg.sender;

    address _token = availableInvestment.tokenAddress;
    uint256 _duration = availableInvestment.duration;
    uint256 _yield = availableInvestment.yield;

    if (_amount <= 0) {
      revert DeFiProtocol__NotEnoughQuantity();
    }

    // It has to be approved earlier
    bool success = IERC20(_token).transferFrom(from, address(this), _amount);

    // If transferFrom failed, revert
    if (!success) {
      revert DeFiProtocol__TransferFromFailure();
    }

    // We need index in the struct in order to properly stake from frontend
    // since deleting only replace the struct with all default values
    investments[from].push(
      Investment(
        from,
        _amount,
        _token,
        block.timestamp,
        _duration,
        _yield,
        0,
        investments[from].length
      )
    );

    emit Stake(from, _amount, _token, block.timestamp);
  }

  function redeemStake(uint256 _index) external returns (bool) {
    Investment memory investment = investments[msg.sender][_index];

    // 1. If the staking is still locked, revert
    require(
      block.timestamp >= investment.startDate + investment.duration * 1 days &&
        investment.startDate != 0,
      "Investment is still locked"
    );

    uint256 rewardAmount = ((investment.amount * (100 + investment.yield)) /
      100) - investment.paidBack;

    // 2. Check if staked token is available
    uint256 _availableBalance = IERC20(investment.stakedToken).balanceOf(
      address(this)
    );

    require(
      _availableBalance > 0,
      "There is no tokens for now, come back later"
    );

    if (_availableBalance >= rewardAmount) {
      delete investments[msg.sender][_index];

      IERC20(investment.stakedToken).transfer(investment.staker, rewardAmount);

      return true;
    } else {
      investment.paidBack += _availableBalance;

      IERC20(investment.stakedToken).transfer(
        investment.staker,
        _availableBalance
      );
    }

    investments[msg.sender][_index] = investment;

    emit Redeem(investment.staker, investment.index);

    return false;
  }

  /**
       BORROWING PART
  */

  // After all formality owner / admin can create a Loan,
  // so somebody will be able to redeem it

  function createLoan(
    address _borrower,
    uint256 _amount,
    uint32 _durationInDays,
    uint32 _interestRate,
    address _borrowedToken
  ) external onlyOwner {
    require((_amount / 10000) * 10000 == _amount, "Amount too small");

    Loan memory loan = Loan(
      _borrower,
      _amount,
      0, // start date
      _durationInDays,
      _interestRate,
      0, // amountRepaid
      _borrowedToken, // we choose it at when creating a loan
      false, // started
      loans[_borrower].length
    );

    loans[_borrower].push(loan);
  }

  function redeemLoan(uint32 _loanIndex) external returns (bool) {
    Loan memory loan = loans[msg.sender][_loanIndex];

    require(
      loan.startDate == 0 && loan.started == false,
      "Loan had already been redeemed"
    );

    address _borrowedToken = loan.borrowedToken;
    uint256 _interestRate = loan.interestRate;
    uint256 amountToWithdraw = loan.amount;
    uint256 availableBalance = IERC20(_borrowedToken).balanceOf(address(this));

    // At this step we add difference between currentYield and interest rate
    // as provision for protocol

    require(
      availableBalance >=
        (amountToWithdraw +
          ((amountToWithdraw * (100 + (_interestRate - currentYield))) / 100)),
      "Sorry, right now there is no enough funds, try again later"
    );

    require(
      msg.sender == loan.borrower,
      "Only borrower can redeem a loan assigned to him"
    );

    loan.started = true;
    loan.startDate = block.timestamp;

    loans[msg.sender][_loanIndex] = loan;

    IERC20(_borrowedToken).transfer(msg.sender, amountToWithdraw);

    return true;
  }

  function repayLoan(uint256 _index, uint256 _amount) external {
    Loan memory loan = loans[msg.sender][_index];

    bool success = IERC20(loan.borrowedToken).transferFrom(
      msg.sender,
      address(this),
      _amount
    );

    // It should throw also if there is not enough allowance
    if (!success) {
      revert DeFiProtocol__TransferFromFailure();
    }

    loan.amountRepaid += _amount;

    // It means that the loan was fully repaid
    if (loan.amountRepaid >= calculateInterest(msg.sender, _index)) {
      delete loans[msg.sender][_index];
      return;
    }

    loans[msg.sender][_index] = loan;
    return;
  }

  /**
    SETTERS
   */

  function setAvailableInvestment(
    address _token,
    uint256 _durationInDays,
    uint256 _yield
  ) external onlyOwner {
    availableInvestment = AvailableInvestment(_token, _durationInDays, _yield);

    currentYield = _yield;
  }

  /**
    GETTERS
   */

  function getAllInvestmentsByAddress(address _of)
    external
    view
    returns (Investment[] memory)
  {
    return investments[_of];
  }

  function getStakedBalance(address _of, uint256 _index)
    external
    view
    returns (uint256)
  {
    Investment memory staker = investments[_of][_index];
    uint256 timeDifference = block.timestamp - staker.startDate;

    return
      calculateReward(
        staker.amount,
        staker.yield,
        timeDifference,
        staker.duration
      );
  }

  function getStaking(address _address, uint256 _index)
    external
    view
    returns (Investment memory)
  {
    return investments[_address][_index];
  }

  function getLoan(address _of, uint256 _index)
    external
    view
    returns (Loan memory)
  {
    return loans[_of][_index];
  }

  function getAvailableInvestment()
    public
    view
    returns (AvailableInvestment memory)
  {
    return availableInvestment;
  }

  /**
    MAINTANANCE PART
   */

  // calculate reward in days
  function calculateReward(
    uint256 _amount,
    uint256 _yield,
    uint256 _timeDifference,
    uint256 _duration
  ) internal pure returns (uint256) {
    uint256 currentBalance;

    // If timeDifferenceInDays is greater than duration
    // we just take final value
    if (_timeDifference > _duration) {
      currentBalance = _amount * ((100 + _yield) / 100);
    } else {
      // If it's less than duration we calculate proportion
      currentBalance =
        _amount *
        ((100 + _yield) / 100) *
        (_timeDifference / _duration);
    }

    return currentBalance;
  }

  function calculateInterest(address _address, uint256 _index)
    public
    view
    returns (uint256)
  {
    Loan memory loan = loans[_address][_index];

    uint256 timeDifferenceInDays = (block.timestamp - loan.startDate) /
      60 /
      60 /
      24;

    // You can repay the loan before time
    // The interest will be the same though
    if (timeDifferenceInDays < loan.duration) {
      timeDifferenceInDays = loan.duration;
    }

    uint256 cumulativeInterest = (loan.interestRate * timeDifferenceInDays) /
      loan.duration;

    return (loan.amount * (100 + (cumulativeInterest))) / 100;
  }

  function withdrawEther(address _to) external onlyOwner {
    uint256 _etherBalance = address(this).balance;

    (bool sent, bytes memory data) = _to.call{ value: _etherBalance }("");

    require(sent, "Failed to send ether");
  }

  // In case somebody would send ETH to the contract

  fallback() external payable {}

  receive() external payable {}
}
