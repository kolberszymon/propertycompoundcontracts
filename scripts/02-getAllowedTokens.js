const { ethers } = require("hardhat");

const allowedTokens = ["0x6c3e1fb1D2449dAa1Ed04BE1a56F135b358C04d6"];

async function main() {
  let [deployer] = await ethers.getSigners();

  let defi = await ethers.getContractAt(
    "DeFiPure",
    "0x1a81Ba1230eE926845429725FaF39d39fc34439D",
    deployer
  );

  const result = await defi.getAvailableInvestments();
  console.log(result);
}

main().catch((e) => {
  console.log(e);
});
