
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  const beneficiary  = '0x448b00525CCd4552a5c9eFbBaAB9304e96500c60';
  // We get the contract to deploy
  const Resolver = await hre.ethers.getContractFactory("Resolver");
  const resolver = await Resolver.deploy();
  console.log("Resolver Deployed to: ",resolver.address);
  const ReNFT = await hre.ethers.getContractFactory("ReNFT");
  const reNFT = await ReNFT.deploy(beneficiary,0,resolver.address);
  console.log("ReNFT deployed to:", reNFT.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
