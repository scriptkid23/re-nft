const { BigNumber } = require("ethers");
const { ethers, deployments, getNamedAccounts } = require("hardhat");
const { expect } = require("chai");
const {
  packPrice,
  takeFee,
  getEvents,
  advanceTime,
  getLatestBlock,
} =  require("./util");

const owner = '0xe3Bb87C766d7537ba75D0214232eFB4a22A6eDcd';

describe("ReNFT contract", function () {
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const [owner] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("ReNFT");

    const hardhatToken = await Token.deploy();

    const ownerBalance = await hardhatToken.balanceOf(owner.address);
    expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
  });
});
