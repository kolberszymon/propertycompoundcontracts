const { deployments, ethers, getNamedAccounts } = require("hardhat");
const { assert, expect } = require("chai");
const { BigNumber } = require("ethers");

describe("Defi", async function () {
  let deployer;
  let notOwner;
  let defi;
  let dai;
  let usdt;
  let stakingAmount;

  beforeEach(async function () {
    stakingAmount = ethers.utils.parseEther("10000");

    [deployer, notOwner] = await ethers.getSigners();

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

    await dai.mint(deployer.address, stakingAmount);

    usdt = await DAI.deploy();
    await usdt.deployed();

    await defi.addAvailableInvestment(dai.address, 365, 10);
    await dai.approve(defi.address, stakingAmount);
  });

  describe("staking", async function () {
    it("doesn't allow for staking not existent investment", async function () {
      await expect(defi.stake(stakingAmount, 2)).to.be.revertedWith(
        "Investment doesn't exist"
      );
    });

    it("reverts not enough allowance", async () => {
      await defi.addAvailableInvestment(usdt.address, 365, 16);
      await expect(defi.stake(100000, 1)).to.be.revertedWith(
        "Not enough allowance"
      );
    });

    it("can stake", async () => {
      await defi.stake(stakingAmount, 0);
      const balance = await dai.balanceOf(defi.address);
      const { staker, amount } = await defi.investments(deployer.address, 0);

      assert.equal(balance.toString(), stakingAmount);
      assert.equal(staker, deployer.address);
      assert.equal(amount.toString(), stakingAmount);
    });

    it("revert redeemStake before the time is up", async () => {
      await defi.stake(stakingAmount, 0);
      await expect(defi.redeemStake(0)).to.be.revertedWith(
        "Investment is still locked"
      );
    });

    it("properly redeemstake whole stake", async () => {
      // Mint for not owner
      await dai.mint(notOwner.address, 10000);
      await dai.connect(notOwner).approve(defi.address, stakingAmount);

      // Initial balance
      const initialBalance = await dai.balanceOf(notOwner.address);

      // Stake
      await defi.connect(notOwner).stake(stakingAmount, 0);

      // Mint, so there will be enough funds in defi
      await dai.mint(defi.address, 10000);

      // Jump one year ahead
      await network.provider.send("evm_increaseTime", [31536000]);

      // Redeem stake
      await defi.connect(notOwner).redeemStake(0);

      // After balance
      let afterBalance = await dai.balanceOf(notOwner.address);

      assert.equal(
        initialBalance
          .mul(100 + 10)
          .div(100)
          .eq(afterBalance),
        true
      );
    });
  });

  describe("borrowing", async () => {
    describe("properly creates a loan", async () => {
      it("owner can create a loan", async () => {
        await defi.createLoan(
          notOwner.address,
          stakingAmount,
          365,
          10,
          dai.address
        );

        const { amount, interestRate, amountRepaid } = await defi.getLoan(
          notOwner.address,
          0
        );

        assert.equal(amount.eq(stakingAmount), true);
        assert.equal(interestRate.toString(), "10");
        assert.equal(amountRepaid.toString(), "0");
      });

      it("not owner can't create a loan", async () => {
        await expect(
          defi
            .connect(notOwner)
            .createLoan(notOwner.address, 1000, 365, 10, dai.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });
    });

    describe("properly repay a loan", async () => {
      it("throws when there is not enough funds ");

      it("paid back a part of amount, and the loan is still here", async () => {
        await dai.mint(defi.address, stakingAmount);

        // Create loan
        await defi.createLoan(
          deployer.address,
          stakingAmount,
          365,
          10,
          dai.address
        );

        // Redeem loan
        await defi.redeemLoan(0);

        await network.provider.send("evm_increaseTime", [31536000]);
        await network.provider.send("evm_mine", []);

        // Repay initial amount and the loan is still there 👺
        await defi.repayLoan(0, ethers.utils.parseEther("9000"));

        // Get loan
        const { amountRepaid } = await defi.getLoan(deployer.address, 0);

        const cumulativeInterest = await defi.calculateInterest(
          deployer.address,
          0
        );

        const difference = cumulativeInterest.sub(amountRepaid);

        assert.equal(difference.eq(ethers.utils.parseEther("2000")), true);
      });
    });
  });

  describe("emergency functions", async () => {
    it("owner can withdraw erc20 tokens", async () => {});

    it("not owner can't withdraw erc20 tokens", async () => {});

    it("owner can withdraw ethers", async () => {});

    it("not owner can't withdraw ethers", async () => {});
  });
});
