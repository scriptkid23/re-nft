const { BigNumber } = require("ethers");
const { ethers, deployments, getNamedAccounts } = require("hardhat");
const { expect } = require("chai");
const {
  packPrice,
  takeFee,
  getEvents,
  advanceTime,
  getLatestBlock,
} = require("./util");

//default values
const MAX_RENT_DURATION = 1; // day
const DAILY_RENT_PRICE = packPrice(0.5); // 2 BNB
const NFT_PRICE = packPrice(3); // 3 BNB

describe("ReNFT contract", function () {
  let owner;
  let addr1;
  let addr2;
  let addrs;

  let StoreContract;
  let tokenContract;
  let ResolverContract;
  let ReNFTContract;
  // beforeEach(async function(){
  //     const Resolver = ethers.getContractFactory("Resolver");
  //     [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
  //     ResolverContract = await Resolver.deploy();
  // });
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    const Store = await ethers.getContractFactory("Store");
    StoreContract = await Store.deploy();
    const token = await ethers.getContractFactory("BNBToken");
    tokenContract = await token.deploy(3000000);

    await StoreContract.connect(addr1).awardItem(
      "http://dummyimage.com/192x100.png/ff4444/ffffff"
    );
    await StoreContract.connect(addr1).awardItem(
      "http://dummyimage.com/138x100.png/dddddd/000000"
    );
    await tokenContract.connect(addr2).awardToken(3000);

    const Resolver = await ethers.getContractFactory("Resolver");
    ResolverContract = await Resolver.deploy();
    ResolverContract.connect(owner).setPaymentToken(1, tokenContract.address);
    const ReNFT = await ethers.getContractFactory("ReNFT");
    ReNFTContract = await ReNFT.deploy(
      owner.address,
      0,
      ResolverContract.address
    );
  });
  describe("Lending", function () {
    it("check owner NFT", async function () {
      expect(await StoreContract.ownerOf(1), "You not owner").to.equal(
        addr1.address
      );
      expect(await StoreContract.ownerOf(2), "You not owner").to.equal(
        addr1.address
      );
    });
    it("trigger lending", async function () {
      ReNFTContract.connect(addr1).lend(
        [StoreContract.address, StoreContract.address],
        [1, 2],
        [MAX_RENT_DURATION, MAX_RENT_DURATION],
        [DAILY_RENT_PRICE, DAILY_RENT_PRICE],
        [NFT_PRICE, NFT_PRICE],
        [1,1]
      );
      // expect(await StoreContract.ownerOf(1), "ReNFT not owner").to.eq(addr1.address);
    });
  });
  describe("Renting", function () {});
  describe("ReturnIt", function () {});
  describe("StopLending", function () {});
  describe("ClaimCollateral", function () {});
});
