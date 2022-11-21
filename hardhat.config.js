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
      runs: 1000,
    },
  },
  // UNCOMMENT WHEN RUNNING SCRIPTS
  networks: {
    hardhat: {
      blockGasLimit: 100000000,
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts: [`${process.env.DEPLOYER}`],
    },
    "ethereum-goerli": {
      url: process.env.ETH_GOERLI_URL,
      accounts: [`${process.env.DEPLOYER}`],
    },
  },
  etherscan: {
    apiKey: {
      polygonMumbai: "6PSEVR9324JTBZSE17YYTBAPRK4XYI2IWP",
    },
  },
  namedAccounts: {
    deployer: 0,
  },
  gasReporter: {
    currency: "USD",
  },
};
