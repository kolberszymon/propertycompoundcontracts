const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();

  let DEFI = await ethers.getContractFactory("DeFiPure", deployer);
  let defi = await DEFI.deploy();

  await defi.deployed();

  console.log("DeFI Deployed to: ", defi.address);
}

main().catch((e) => {
  console.log(e);
});
