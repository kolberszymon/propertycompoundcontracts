const { ethers } = require("hardhat");

const allowedTokens = ["0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00"];

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
