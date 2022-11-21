const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const defiProtocol = await deploy("DeFiProtocol", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  log(`DeFiProtocol deployed at ${defiProtocol.address}`);
  const defiDeployed = await hre.ethers.getContractAt(
    "DeFiProtocol",
    defiProtocol.address
  );
  await defiDeployed.addAllowedToken(
    "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853"
  );
  await defiDeployed.addAllowedToken(
    "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
  );
};

module.exports.tags = ["all"];
