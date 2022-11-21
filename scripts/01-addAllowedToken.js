const { ethers } = require("hardhat");

const allowedInvestments = [
  {
    tokenAddress: "0x6c3e1fb1D2449dAa1Ed04BE1a56F135b358C04d6",
    duration: 365,
    interestRate: 14,
  },
];

async function main() {
  let [deployer] = await ethers.getSigners();

  let defi = await ethers.getContractAt(
    "DeFiPure",
    "0x1a81Ba1230eE926845429725FaF39d39fc34439D",
    deployer
  );

  for (const investment of allowedInvestments) {
    await defi.addAllowedInvestment(
      investment.tokenAddress,
      investment.duration,
      investment.interestRate
    );
    console.log("Token allowed: ", investment.tokenAddress);
  }
}

main().catch((e) => {
  console.log(e);
});
