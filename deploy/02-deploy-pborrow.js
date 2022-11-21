const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const pBorrow = await deploy("PBorrow", {
    from: deployer,
    args: ["0x5fbdb2315678afecb367f032d93f642f64180aa3"],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  log(`pBorrow deployed at ${pBorrow.address}`);
};

module.exports.tags = ["all"];
