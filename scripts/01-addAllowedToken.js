const { ethers } = require("hardhat");

const allowedInvestments = [
  {
    tokenAddress: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    duration: 10,
    interestRate: 14,
  },
];

async function main() {
  let [deployer] = await ethers.getSigners();

  let defi = await ethers.getContractAt(
    "DeFiPure",
    "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    deployer
  );

  for (const investment of allowedInvestments) {
    await defi.addAllowedInvestment(
      investment.tokenAddress,
      investment.duration,
      investment.interestRate
    );
    console.log("Investment added: ", investment.tokenAddress);
  }
}

main().catch((e) => {
  console.log(e);
});
