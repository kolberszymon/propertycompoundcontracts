require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("dotenv").config();
require("solidity-coverage");

module.exports = {
  solidity: "0.8.9",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  // UNCOMMENT WHEN RUNNING SCRIPTS
  networks: {
    localhost: {
      blockGasLimit: 100000000,
      accounts: [`${process.env.DEPLOYER}`, `${process.env.NOT_OWNER}`],
    },
    polygon: {
      url: process.env.POLYGON_URL,
      accounts: [`${process.env.DEPLOYER}`],
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts: [`${process.env.DEPLOYER}`, `${process.env.NOT_OWNER}`],
    },
    "ethereum-goerli": {
      url: process.env.ETH_GOERLI_URL,
      accounts: [`${process.env.DEPLOYER}`, `${process.env.NOT_OWNER}`],
    },
  },
  etherscan: {
    apiKey: {
      polygon: "6PSEVR9324JTBZSE17YYTBAPRK4XYI2IWP",
    },
  },
  namedAccounts: {
    deployer: 0,
    notOwner: 1,
  },
  gasReporter: {
    currency: "USD",
    coinmarketcap: "3ba17cea-d50a-46ef-8b70-96d487844b5e",
    gasPrice: 18,
  },
};
