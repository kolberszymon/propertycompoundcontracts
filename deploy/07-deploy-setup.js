const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();

  let DEFI = await ethers.getContractFactory("DeFiPure", deployer);
  let defi = await DEFI.deploy();

  await defi.deployed();

  console.log("DeFI Deployed to: ", defi.address);

  let DAI = await ethers.getContractFactory("DAI", deployer);
  let dai = await DAI.deploy();

  await dai.deployed();

  console.log("DAI Deployed to: ", dai.address);

  await dai.mint(deployer.address, 100000000000000);

  console.log("DAI minted :)");

  await defi.addAllowedInvestment(dai.address, 120, 14);

  console.log("DAI allowed");

  let USDT = await ethers.getContractFactory("USDT", deployer);
  let usdt = await USDT.deploy();

  await usdt.deployed();

  console.log("USDT Deployed to: ", usdt.address);

  await usdt.mint(deployer.address, 100000);

  console.log("USDT minted :)");

  await defi.addAllowedInvestment(usdt.address, 50, 30);

  console.log("USDT allowed");
}

main().catch((e) => {
  console.log(e);
});
