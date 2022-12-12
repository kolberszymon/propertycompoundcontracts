const { network } = require("hardhat");

const [deployer] = await ethers.getSigners();

let defi = await ethers.getContractAt(
  "DeFiPure",
  "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  deployer
);

await defi.getStaking("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", 1);

// Increase time by one year
await network.provider.send("evm_increaseTime", [31536000]);

await network.provider.send("evm_mine", []);
