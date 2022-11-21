// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error DeFiProtocol__NotEnoughQuantity();
error DeFiProtocol__TokenNotSupported();
error DeFiProtocol__NotSufficientBalance();
error DeFiProtocol__TransferFromFailure();
error DeFiProtocol__StakingStillLocked();

// Change to be clean loan

contract DeFiPure is Ownable {
  struct Investment {
    address staker;
    uint256 amount;
    address stakedToken;
    uint256 startDate;
    uint256 duration;
    uint256 interest;
    uint256 paidBack;
  }

  struct Loan {
    address borrower;
    uint256 amount;
    uint256 startDate;
    uint256 duration;
    uint256 interestRate;
    uint256 amountRepaid;
    uint256 availableToBorrow;
  }

  struct AvailableInvestment {
    address tokenAddress;
    uint256 duration;
    uint256 interestRate;
  }

  mapping(address => bool) public isTokenAllowed;
  mapping(address => Investment[]) public stakers;
  mapping(uint256 => address) public tokenIdToAddress;
  mapping(address => Loan[]) public loans;

  AvailableInvestment[] private allowedInvestments;

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

  constructor() Ownable() {}

  /**
      STAKING PART
   */

  function stake(uint256 _amount, uint32 _investmentIndex)
    external
    checkIfTokenIsAllowed(allowedInvestments[_investmentIndex].tokenAddress)
    checkAllowance(_amount, allowedInvestments[_investmentIndex].tokenAddress)
  {
    address from = msg.sender;
    address _token = allowedInvestments[_investmentIndex].tokenAddress;
    uint256 _duration = allowedInvestments[_investmentIndex].duration;
    uint256 _interestRate = allowedInvestments[_investmentIndex].interestRate;

    if (_amount <= 0) {
      revert DeFiProtocol__NotEnoughQuantity();
    }

    // It has to be approved earlier
    bool success = IERC20(_token).transferFrom(from, address(this), _amount);

    // If transferFrom failed, revert
    if (!success) {
      revert DeFiProtocol__TransferFromFailure();
    }

    stakers[from].push(
      Investment(
        from,
        _amount,
        _token,
        block.timestamp,
        _duration,
        _interestRate,
        0
      )
    );

    emit Stake(from, _amount, _token, block.timestamp);
  }

  function redeemStake(uint256 _index) external returns (bool) {
    Investment memory staker = stakers[msg.sender][_index];

    // 1. If the staking is still locked, revert
    require(
      block.timestamp >= staker.startDate + staker.duration * 1 days &&
        staker.startDate != 0,
      "Staking is still locked"
    );

    uint256 rewardAmount = ((staker.amount * (100 + staker.interest)) / 100) -
      staker.paidBack;

    // 2. Check if staked token is available

    // 2a. If yes pay out the same token
    if (IERC20(staker.stakedToken).balanceOf(address(this)) >= rewardAmount) {
      delete stakers[msg.sender][_index];

      IERC20(staker.stakedToken).transfer(staker.staker, rewardAmount);

      return true;
    } else {
      // 2b. If no, iterate over an array of allowed token and try to pay out from it
      for (uint256 i = 0; i < allowedInvestments.length; i++) {
        uint256 _balance = IERC20(allowedInvestments[i].tokenAddress).balanceOf(
          address(this)
        );

        if (_balance == 0) {
          continue;
        }

        rewardAmount =
          ((staker.amount * (100 + staker.interest)) / 100) -
          staker.paidBack;

        if (_balance >= rewardAmount) {
          delete stakers[msg.sender][_index];

          IERC20(allowedInvestments[i].tokenAddress).transfer(
            staker.staker,
            rewardAmount
          );

          return true;
        } else {
          staker.paidBack += _balance;

          IERC20(allowedInvestments[i].tokenAddress).transfer(
            staker.staker,
            _balance
          );
        }
      }
    }
    stakers[msg.sender][_index] = staker;
    return false;
  }

  // /**
  //     BORROWING PART
  //  */

  // After all formality owner / admin can create a Loan,
  // so somebody will be able to redeem it
  function createLoan(
    uint256 _amount,
    address _borrower,
    uint32 _durationInDays,
    uint32 _lendingRate
  ) external onlyOwner {
    Loan memory loan = Loan(
      _borrower,
      _amount,
      block.timestamp,
      _durationInDays,
      _lendingRate,
      0,
      _amount
    );

    loans[_borrower].push(loan);
  }

  function redeemLoan(
    uint32 _loanIndex,
    address _preferableToken,
    uint256 _amount
  ) external checkIfTokenIsAllowed(_preferableToken) returns (bool) {
    Loan memory loan = loans[msg.sender][_loanIndex];

    require(
      loan.startDate != 0 && loan.availableToBorrow > 0,
      "Loan does not exist, or it had already been redeemed"
    );

    uint256 amountToWithdraw = _amount;

    // It ensures that _amount will be in proper range, i.e. 0 < _amount < availableToBorrow
    if (_amount == 0 || _amount >= loan.availableToBorrow) {
      amountToWithdraw = loan.availableToBorrow;
    }

    // 2a. If yes pay out the same token
    if (IERC20(_preferableToken).balanceOf(address(this)) >= amountToWithdraw) {
      loan.availableToBorrow -= amountToWithdraw;
      loans[msg.sender][_loanIndex] = loan;

      IERC20(_preferableToken).transfer(msg.sender, amountToWithdraw);

      return true;
    } else {
      // 2b. If no, iterate over an array of allowed token and try to pay out from it
      for (uint256 i = 0; i < allowedInvestments.length; i++) {
        uint256 _balance = IERC20(allowedInvestments[i].tokenAddress).balanceOf(
          address(this)
        );

        if (_balance == 0) {
          continue;
        }

        if (_balance >= amountToWithdraw) {
          loan.availableToBorrow -= amountToWithdraw;
          loans[msg.sender][_loanIndex] = loan;

          IERC20(allowedInvestments[i].tokenAddress).transfer(
            msg.sender,
            amountToWithdraw
          );

          return true;
        } else {
          loan.availableToBorrow -= _balance;
          loans[msg.sender][_loanIndex] = loan;

          IERC20(allowedInvestments[i].tokenAddress).transfer(
            msg.sender,
            _balance
          );
        }
      }
    }

    return false;
  }

  function repayLoan(
    uint256 _index,
    address _token,
    uint256 _amount
  ) external checkIfTokenIsAllowed(_token) checkAllowance(_amount, _token) {
    Loan memory loan = loans[msg.sender][_index];

    bool success = IERC20(_token).transferFrom(
      msg.sender,
      address(this),
      _amount
    );

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

  fallback() external payable {}

  function removeFromArray(address _token) internal {
    AvailableInvestment[] memory _allowedInvestments = allowedInvestments;

    for (uint256 i = 0; i < _allowedInvestments.length - 1; i++) {
      if (_allowedInvestments[i].tokenAddress == _token) {
        _allowedInvestments[i] = _allowedInvestments[
          _allowedInvestments.length - 1
        ];
        delete _allowedInvestments[_allowedInvestments.length - 1];
      }
    }

    delete allowedInvestments;

    for (uint256 i = 0; i < _allowedInvestments.length - 1; i++) {
      allowedInvestments.push(_allowedInvestments[i]);
    }
  }

  function addAllowedInvestment(
    address _token,
    uint256 _durationInDays,
    uint256 _interestRate
  ) external onlyOwner {
    require(!isTokenAllowed[_token], "Token is already allowed");
    isTokenAllowed[_token] = true;
    allowedInvestments.push(
      AvailableInvestment(_token, _durationInDays, _interestRate)
    );
  }

  function removeAllowedToken(uint256 _investmentIndex) external onlyOwner {
    AvailableInvestment memory availableInvestment = allowedInvestments[
      _investmentIndex
    ];
    require(
      isTokenAllowed[availableInvestment.tokenAddress],
      "Chill... Token is not allowed anyway"
    );
    isTokenAllowed[availableInvestment.tokenAddress] = false;
    removeFromArray(availableInvestment.tokenAddress);
  }

  function getAllInvestmentsByAddress(address _of)
    external
    view
    returns (Investment[] memory)
  {
    return stakers[_of];
  }

  function calculateReward(uint256 _interest, uint256 _timeDifference)
    internal
    pure
    returns (uint256)
  {
    // Calculate interest per second

    uint256 secondsInYear = 31536000;
    uint256 returnsPerSecond = _interest / secondsInYear;

    return _timeDifference * returnsPerSecond;
  }

  function getStakedBalance(address _of, uint256 _index)
    external
    view
    returns (uint256)
  {
    Investment memory staker = stakers[_of][_index];
    uint256 timeDifference = block.timestamp - staker.startDate;

    return calculateReward(staker.interest, timeDifference);
  }

  function getStaking(address _address, uint256 _index)
    external
    view
    returns (Investment memory)
  {
    return stakers[_address][_index];
  }

  function calculateInterest(address _address, uint256 _index)
    internal
    view
    returns (uint256)
  {
    Loan memory loan = loans[_address][_index];
    uint256 timeDifference = block.timestamp - loan.startDate;

    uint256 secondsInYear = 31536000;

    // set the minimum calculated interest to yearly,
    // If it's greater the interest will be also
    if (timeDifference < secondsInYear) {
      timeDifference = secondsInYear;
    }

    uint256 interestPerSecond = loan.interestRate / secondsInYear;

    return (loan.amount * (100 + (interestPerSecond * timeDifference))) / 100;
  }

  function getAvailableInvestments()
    public
    view
    returns (AvailableInvestment[] memory)
  {
    return allowedInvestments;
  }
}
