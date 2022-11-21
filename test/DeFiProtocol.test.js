const { deployments, ethers, getNamedAccounts } = require("hardhat");
const { assert, expect } = require("chai");

describe("Defi", async function () {
  let deployer;
  // let addr1;
  let defi;
  let dai;
  let dai1;
  let stakingAmount = 10000;
  let pLend;
  let pBorrow;

  beforeEach(async function () {
    [deployer] = await ethers.getSigners();

    // Creating DeFi contract
    const DEFI = await ethers.getContractFactory("DeFiPure", deployer);
    defi = await DEFI.deploy();
    await defi.deployed();
    defi.connect(deployer);

    // Create dai contract so we can test staking
    const DAI = await ethers.getContractFactory("DAI", deployer);
    dai = await DAI.deploy();
    await dai.deployed();
    dai.connect(deployer);
    await dai.mint(deployer.address, 1000);

    dai1 = await DAI.deploy();
    await dai1.deployed();

    await defi.addAllowedInvestment(dai.address, 365, 16);
    await dai.approve(defi.address, 100000);
  });

  describe("staking", async function () {
    it("doesn't allow for staking not allowed token", async function () {
      await expect(defi.stake(10000, 2)).to.be.revertedWith(
        "Token not allowed"
      );
    });

    it("reverts not enough allowance", async () => {
      await defi.addAllowedInvestment(dai1.address, 365, 16);
      await expect(defi.stake(10000, 0)).to.be.revertedWith(
        "Not enough allowance"
      );
    });

    it("can stake", async () => {
      await defi.stake(stakingAmount, 0);
      const balance = await dai.balanceOf(defi.address);
      const { staker, amount } = await defi.stakers(deployer.address, 0);

      assert.equal(balance, stakingAmount);
      assert.equal(staker, deployer.address);
      assert.equal(amount, stakingAmount);
    });

    it("revert redeemStake before the time is up", async () => {
      await defi.stake(stakingAmount, 0);
      await expect(defi.redeemStake(0)).to.be.revertedWith(
        "Staking is still locked"
      );
    });

    it("properly redeemstake", async () => {
      await defi.stake(stakingAmount, 0);
      await network.provider.send("evm_increaseTime", [31536000]);

      await defi.redeemStake(0);

      let before_staked = await defi.getStaking(deployer.address, 0);

      // Redeemed all available funds but still has some back
      assert.equal(before_staked.paidBack, stakingAmount);

      await dai.mint(defi.address, 1);

      let before_balanceOfContract = await dai.balanceOf(defi.address);

      await defi.redeemStake(0);

      let after_staked = await defi.getStaking(deployer.address, 0);

      // Stake has been deleted
      assert.equal(after_staked.startDate, 0);

      let after_balanceOfContract = await dai.balanceOf(defi.address);

      // It only took remaining tokens
      assert.equal(after_balanceOfContract, before_balanceOfContract - 1600);
    });
  });

  describe("borrowing", async () => {
    it("properly creates a loan", async () => {});

    it("properly redeem a loan", async () => {});

    it("properly repay a loan", async () => {});
  });
});
