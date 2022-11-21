const { network } = require("hardhat");
const hre = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdt = await deploy("USDT", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  log(`usdt deployed at ${usdt.address}`);

  const usdtDeployed = await hre.ethers.getContractAt("USDT", usdt.address);
  await usdtDeployed.mint("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 1000);
};

module.exports.tags = ["all"];
