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

contract DeFiPure is Ownable {
  using SafeMath for uint256;

  struct Investment {
    address staker;
    uint256 amount;
    address stakedToken;
    uint256 startDate;
    uint256 duration;
    uint256 interest;
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
    uint256 interestRate;
    uint256 index;
  }

  mapping(address => Investment[]) public investments;
  mapping(address => Loan[]) public loans;

  AvailableInvestment[] private availableInvestments;

  event Stake(
    address indexed stakerAddress,
    uint256 amount,
    address stakedToken,
    uint256 startDate
  );
  event Redeem(address indexed stakerAddress, uint256 indexed investmentIndex);

  // Modifier to check token allowance
  modifier checkAllowance(uint256 amount, address token) {
    IERC20 _token = IERC20(token);
    require(
      _token.allowance(msg.sender, address(this)) >= amount,
      "Not enough allowance"
    );
    _;
  }

  modifier checkIfInvestmentExist(uint256 _index) {
    require(_index < availableInvestments.length, "Investment doesn't exist");
    _;
  }

  constructor() Ownable() {}

  /**
      STAKING PART
   */

  function stake(uint256 _amount, uint32 _investmentIndex)
    external
    checkIfInvestmentExist(_investmentIndex)
    checkAllowance(_amount, availableInvestments[_investmentIndex].tokenAddress)
  {
    address from = msg.sender;
    address _token = availableInvestments[_investmentIndex].tokenAddress;
    uint256 _duration = availableInvestments[_investmentIndex].duration;
    uint256 _interestRate = availableInvestments[_investmentIndex].interestRate;

    require(_token != address(0), "Investment was deleted");

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
        _interestRate,
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

    uint256 rewardAmount = ((investment.amount * (100 + investment.interest)) /
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
      IERC20(investment.stakedToken).transfer(
        investment.staker,
        _availableBalance
      );

      investment.paidBack += _availableBalance;
    }
    investments[msg.sender][_index] = investment;

    emit Redeem(investment.staker, investment.index);

    return false;
  }

  // /**
  //     BORROWING PART
  //  */

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
    uint256 amountToWithdraw = loan.amount;
    uint256 availableBalance = IERC20(_borrowedToken).balanceOf(address(this));

    require(
      availableBalance >= amountToWithdraw,
      "Sorry, right now there is no enough funds, try again later"
    );

    // 2a. If yes pay out the same token

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
    MAINTANANCE PART
   */

  function withdrawERC20(
    address _tokenAddress,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    IERC20(_tokenAddress).transfer(_to, _amount);
  }

  function withdrawEther(address _to) external onlyOwner {
    uint256 _etherBalance = address(this).balance;

    (bool sent, bytes memory data) = _to.call{ value: _etherBalance }("");

    require(sent, "Failed to send ether");
  }

  function addAvailableInvestment(
    address _token,
    uint256 _durationInDays,
    uint256 _interestRate
  ) external onlyOwner {
    availableInvestments.push(
      AvailableInvestment(
        _token,
        _durationInDays,
        _interestRate,
        availableInvestments.length
      )
    );
  }

  function removeAvailableInvestment(uint256 _investmentIndex)
    external
    onlyOwner
  {
    delete availableInvestments[_investmentIndex];
  }

  function getAllInvestmentsByAddress(address _of)
    external
    view
    returns (Investment[] memory)
  {
    return investments[_of];
  }

  function calculateReward(uint256 _interest, uint256 _timeDifference)
    internal
    pure
    returns (uint256)
  {
    // Calculate interest per second

    // There can be different timeDiffernces in the future
    uint256 returnsPerSecond = _interest / _timeDifference;

    return _timeDifference * returnsPerSecond;
  }

  function getStakedBalance(address _of, uint256 _index)
    external
    view
    returns (uint256)
  {
    Investment memory staker = investments[_of][_index];
    uint256 timeDifference = block.timestamp - staker.startDate;

    return calculateReward(staker.interest, timeDifference);
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

    // In order to prevent repayments in 10 seconds for 0.0001%
    if (timeDifferenceInDays < loan.duration) {
      timeDifferenceInDays = loan.duration;
    }

    uint256 cumulativeInterest = (loan.interestRate * timeDifferenceInDays) /
      loan.duration;

    return (loan.amount * (100 + (cumulativeInterest))) / 100;
  }

  function getAvailableInvestments()
    public
    view
    returns (AvailableInvestment[] memory)
  {
    return availableInvestments;
  }

  fallback() external payable {}

  receive() external payable {}
}
