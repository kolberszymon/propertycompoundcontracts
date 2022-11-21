// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.9;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Context.sol";
// import "./ERC20DeFi.sol";
// import "hardhat/console.sol";

// error DeFiProtocol__NotEnoughQuantity();
// error DeFiProtocol__TokenNotSupported();
// error DeFiProtocol__NotSufficientBalance();
// error DeFiProtocol__TransferFromFailure();
// error DeFiProtocol__StakingStillLocked();

// contract DeFiProtocol is Ownable {
//   struct Staker {
//     address staker;
//     uint256 amount;
//     address stakedToken;
//     uint256 startDate;
//     uint256 duration;
//     uint256 stakingRate;
//   }

//   // Let's just calculate it when the person wants to pay back
//   // if he wants to pay back before the end it just calculate

//   struct Borrower {
//     address borrower;
//     uint256 amount;
//     uint256 startDate;
//     uint256 duration;
//     uint256 lendingRate;
//   }

//   ERC20DeFi private immutable pLend;
//   ERC20DeFi private immutable pBorrow;

//   address[] private allowedTokens;
//   mapping(address => Staker[]) private staking;
//   mapping(address => Borrower[]) private borrowing;

//   event Stake(
//     address indexed stakerAddress,
//     uint256 amount,
//     address stakedToken,
//     uint256 startDate
//   );
//   event Redeem();
//   event Borrow();

//   // Modifier to check token allowance
//   modifier checkAllowance(uint256 amount, address token) {
//     IERC20 _token = IERC20(token);
//     require(
//       _token.allowance(msg.sender, address(this)) >= amount,
//       "Not enough allowance"
//     );
//     _;
//   }

//   modifier checkIfTokenIsAllowed(address token) {
//     address[] memory allTokens = allowedTokens;

//     for (uint256 i = 0; i < allTokens.length; i++) {
//       if (allTokens[i] == token) {
//         _;
//         return;
//       }
//     }

//     revert DeFiProtocol__TokenNotSupported();
//   }

//   constructor() Ownable() {
//     pLend = new ERC20DeFi("pLend", "pL");
//     pBorrow = new ERC20DeFi("pBorrow", "pB");
//   }

//   // Stake token
//   function stake(uint256 _amount, address _token)
//     external
//     checkIfTokenIsAllowed(_token)
//     checkAllowance(_amount, _token)
//   {
//     address from = msg.sender;

//     if (_amount <= 0) {
//       revert DeFiProtocol__NotEnoughQuantity();
//     }

//     // It has to be approved earlier
//     bool success = IERC20(_token).transferFrom(from, address(this), _amount);

//     // If transferFrom failed, revert
//     if (!success) {
//       revert DeFiProtocol__TransferFromFailure();
//     }

//     // Push staker to the array, (is it really needed?)
//     staking[from].push(Staker(from, _amount, _token, block.timestamp, 365));

//     // I think we don't need to mint pToken here,
//     // since the APY is constant we can just display it,
//     // and mint when he'll be withdrawing

//     emit Stake(from, _amount, _token, block.timestamp);
//   }

//   // First we have to check / show user what staking is available to him
//   // Check what happens if the index doesn't exist
//   function redeemStake(uint256 _index) public {
//     Staker memory staker = staking[msg.sender][_index];

//     // If the staking is still locked, revert
//     require(
//       block.timestamp >= staker.startDate + staker.duration * 1 days,
//       "Staking is still locked"
//     );

//     // Deleting from Staker account
//     delete staking[msg.sender][_index];

//     // Create
//     // pLend.lend(msg.sender, staker.amount);

//     emit Redeem();
//   }

//   // It should be onlyowner because we're the one that will emit the tokens
//   // amount is 50% of property value

//   function borrow(uint256 _amount, address _borrower) public onlyOwner {
//     if (_amount <= 0) {
//       revert DeFiProtocol__NotEnoughQuantity();
//     }

//     // Adding borrower to an array
//     borrowing[_borrower].push(
//       Borrower(_borrower, _amount, block.timestamp, 365)
//     );
//     // Minting pBorrow tokens to _borrower address
//     pBorrow.borrow(_borrower, _amount);

//     emit Borrow();
//   }

//   // Allow you to see how many tokens of given ERC20 this smart contract owns
//   function getSmartContractBalance(address _token)
//     external
//     view
//     returns (uint256)
//   {
//     return IERC20(_token).balanceOf(address(this));
//   }

//   function getStaker(address staker) public view returns (Staker[] memory) {
//     return staking[staker];
//   }

//   function addAllowedToken(address _token) public onlyOwner {
//     allowedTokens.push(_token);
//   }

//   function getAllowedTokens() public view returns (address[] memory) {
//     return allowedTokens;
//   }
// }
