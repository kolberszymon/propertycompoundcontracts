const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const pLend = await deploy("PLend", {
    from: deployer,
    args: ["0x5fbdb2315678afecb367f032d93f642f64180aa3"],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  log(`pLend deployed at ${pLend.address}`);
};

module.exports.tags = ["all"];
