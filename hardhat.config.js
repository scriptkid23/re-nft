require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();
require("hardhat-gas-reporter");


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    ropsten_testnet: {
      url: process.env.ROPSTEN_TESTNET_URL,
      chainId: 3,
      gasPrice: 20000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    rinkeby_testnet: {
      url: process.env.RINKEBY_TESTNET_URL,
      chainId: 4,
      gasPrice: 20000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    polygon_testnet: {
      url: process.env.POLYGON_TESTNET_URL,
      chainId: 80001,
      gasPrice: 20000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    bsc: {
      url: process.env.BSC_TESTNET_URL,
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  },
};
