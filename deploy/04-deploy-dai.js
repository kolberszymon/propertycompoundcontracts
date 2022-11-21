const { network } = require("hardhat");
const hre = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();

  let DAI = await ethers.getContractFactory("DAI", deployer);
  let dai = await DAI.deploy();

  await dai.deployed();

  console.log("DAI Deployed to: ", dai.address);

  const daiDeployed = await hre.ethers.getContractAt("DAI", dai.address);
  await daiDeployed.mint(deployer.address, 100000000000000);
}

main().catch((e) => {
  console.log(e);
});
