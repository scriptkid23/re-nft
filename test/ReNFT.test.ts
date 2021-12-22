import { E721 } from "./../frontend/src/hardhat/typechain/E721";
import { Resolver } from "./../frontend/src/hardhat/typechain/Resolver";
import { BigNumber, ContractReceipt, ContractTransaction } from "ethers";
import { expect } from "./chai-setup";
import { ethers } from "hardhat";
import { ReNFT } from "../frontend/src/hardhat/typechain/ReNFT";
import { USDC } from "../frontend/src/hardhat/typechain/USDC";
import { BNB } from "../frontend/src/hardhat/typechain/BNB";
import { IERC721 } from "../frontend/src/hardhat/typechain/IERC721";
import {
  packPrice,
  takeFee,
  getEvents,
  advanceTime,
  getLatestBlock,
} from "./util";

const MAX_RENT_DURATION = 1; // 1 day
const DAILY_RENT_PRICE = packPrice(0.5);
const NFT_PRICE = packPrice(3.5);
const PAYMENT_TOKEN_WETH = 1; // default token is WETH
const PAYMENT_TOKEN_USDC = 3;

const SECONDS_IN_A_DAY = 86400;
const DP18 = ethers.utils.parseEther("1");
const ERC20_SEND_AMT = ethers.utils.parseEther("10");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe("ReNFT Contract", function () {
  var bnbContract: BNB,
    e721Contract: E721,
    usdcContract: USDC,
    reNFTContract: ReNFT,
    resolverContract: Resolver,
    txn: ContractTransaction,
    receipt:ContractReceipt;
  before(async function () {
    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
    this.alice = this.signers[1];
    this.bob = this.signers[2];
    this.carol = this.signers[3];
    this.minter = this.signers[4];
    this.signer = this.signers[5];
    this.fundWallet = this.signers[6];
    this.beneficiary = this.signers[7];
    this.nft = ZERO_ADDRESS;
    this.BNB = await ethers.getContractFactory("BNB");
    this.E721 = await ethers.getContractFactory("E721");
    this.USDC = await ethers.getContractFactory("USDC");
    this.ReNFT = await ethers.getContractFactory("ReNFT");
    this.Resolver = await ethers.getContractFactory("Resolver");
  });
  beforeEach(async function () {});
  context("Start", function () {
    it("should it work", async function () {
      bnbContract = await this.BNB.deploy(100000);
      e721Contract = await this.E721.deploy();
      usdcContract = await this.USDC.deploy(this.owner.address);
      resolverContract = await this.Resolver.deploy();
      reNFTContract = await this.ReNFT.deploy(
        this.beneficiary.address,
        0,
        resolverContract.address
      );

      console.log("bnbContract address: ", bnbContract.address);
      console.log("e721Contract address: ", e721Contract.address);
      console.log("usdcContract address: ", usdcContract.address);
      console.log("resolverContract address:", resolverContract.address);
      console.log("reNFTContract address: ", reNFTContract.address);

      // alice have 2 NFT, 0 BNB, 0 USDC
      e721Contract.connect(this.alice).award();
      e721Contract.connect(this.alice).award();

      e721Contract
        .connect(this.alice)
        .setApprovalForAll(reNFTContract.address, true);
      expect(await e721Contract.ownerOf(1)).to.eq(this.alice.address);
      expect(await e721Contract.ownerOf(2)).to.eq(this.alice.address);

      // bob have 0 NFT, 1000 BNB, 1000 USDC
      usdcContract.connect(this.bob).faucet();
      bnbContract.connect(this.bob).faucet();

      resolverContract
        .connect(this.owner)
        .setPaymentToken(1, bnbContract.address);
      resolverContract
        .connect(this.owner)
        .setPaymentToken(2, usdcContract.address);

      expect(await resolverContract.getPaymentToken(1)).to.eq(
        bnbContract.address
      );
      expect(await resolverContract.getPaymentToken(2)).to.eq(
        usdcContract.address
      );

      // start lending by alice
      e721Contract.connect(this.alice).approve(reNFTContract.address, 1);

      console.log("Owner of token #1: ", await e721Contract.ownerOf(1));
      console.log(
        "Approved of token #1: ",
        await e721Contract.connect(this.alice).getApproved(1)
      );

      txn = await reNFTContract
        .connect(this.alice)
        .lend(
          [e721Contract.address, e721Contract.address],
          [1, 2],
          [MAX_RENT_DURATION, MAX_RENT_DURATION],
          [DAILY_RENT_PRICE, DAILY_RENT_PRICE],
          [NFT_PRICE, packPrice(3)],
          [1, 1]
        );
      receipt = await txn.wait();
      console.log(receipt);
      expect(await e721Contract.connect(this.bob).ownerOf(1)).to.eq(
        reNFTContract.address
      );

      // start renting by bob
      await bnbContract
        .connect(this.bob)
        .approve(reNFTContract.address, ERC20_SEND_AMT);
      txn = await reNFTContract
        .connect(this.bob)
        .rent([e721Contract.address], [1], [1], [MAX_RENT_DURATION]);
        receipt = await txn.wait();

        let data = (getEvents(receipt.events ?? [],"Rented")[0]);
        console.log(data)

      expect(
        await bnbContract.allowance(this.bob.address, reNFTContract.address)
      ).to.eq(ethers.utils.parseEther("6"));
     
      // test stop Lending hope revert
      // expect(reNFTContract.connect(this.alice).stopLending([e721Contract.address],[1],[1])).to.be.reverted;
      
      txn = await reNFTContract.connect(this.bob).returnIt([e721Contract.address],[1],[1]);
      receipt = await txn.wait();
      console.log(receipt.events[]);
      // const e = getEvents(receipt.events ?? [], "Returned");
      // console.log(e)

    });
  });
});
