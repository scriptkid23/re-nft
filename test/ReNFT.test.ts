import { E721 } from "./../frontend/src/hardhat/typechain/E721";
import { Resolver } from "./../frontend/src/hardhat/typechain/Resolver";
import {
  BigNumber,
  ContractReceipt,
  ContractTransaction,
  Signer,
} from "ethers";
import { expect } from "./chai-setup";
import { ethers } from "hardhat";
import { ReNFT } from "../frontend/src/hardhat/typechain/ReNFT";
import { USDC } from "../frontend/src/hardhat/typechain/USDC";
import { BNB } from "../frontend/src/hardhat/typechain/BNB";
import { Event } from "@ethersproject/contracts/lib";
import { ERC20 } from "../frontend/src/hardhat/typechain/ERC20";
import { Utils } from "../frontend/src/hardhat/typechain/Utils";
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
const PAYMENT_TOKEN_BNB = 1; // default token is BNB
const PAYMENT_TOKEN_USDC = 2;

const SECONDS_IN_A_DAY = 86400;
const DP18 = ethers.utils.parseEther("1");
const ERC20_SEND_AMT = ethers.utils.parseEther("1000");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

type lendArgs = {
  nftAddresses?: string[];
  tokenIds: number[];
  maxRentDurations?: number[];
  dailyRentPrices?: string[];
  nftPrices?: string[];
  expectedLendingIds?: number[];
};
const captureBalances = async (
  accs: (ReNFT)[],
  coins: ERC20[]
) => {
  const balances = [];
  for (let i = 0; i < accs.length; i++) {
    for (let j = 0; j < coins.length; j++) {
      balances.push(await coins[j].balanceOf(accs[i].address));
    }
  }
  return balances;
};
describe("ReNFT Contract", function () {
  var bnbContract: BNB,
    e721Contract: E721,
    usdcContract: USDC,
    reNFTContract: ReNFT,
    Utils: Utils,
    resolverContract: Resolver,
    txn: ContractTransaction,
    receipt: ContractReceipt,
    owner: any,
    lender: any,
    renter: any,
    fundWallet: any,
    beneficiary: any;

  // context("Lending", function () {
  //   beforeEach(async function () {
  //     this.signers = await ethers.getSigners();
  //     owner = this.signers[0];
  //     lender = this.signers[1];
  //     renter = this.signers[2];
  //     fundWallet = this.signers[4];
  //     beneficiary = this.signers[5];
  //     this.BNB = await ethers.getContractFactory("BNB");
  //     this.E721 = await ethers.getContractFactory("E721");
  //     this.USDC = await ethers.getContractFactory("USDC");
  //     this.ReNFT = await ethers.getContractFactory("ReNFT");
  //     this.Resolver = await ethers.getContractFactory("Resolver");

  //     bnbContract = await this.BNB.deploy(100000);
  //     e721Contract = await this.E721.deploy();
  //     usdcContract = await this.USDC.deploy(owner.address);
  //     resolverContract = await this.Resolver.deploy();
  //     reNFTContract = await this.ReNFT.deploy(
  //       beneficiary.address,
  //       0,
  //       resolverContract.address
  //     );
  //     // console.log("bnbContract address: ", bnbContract.address);
  //     // console.log("e721Contract address: ", e721Contract.address);
  //     // console.log("usdcContract address: ", usdcContract.address);
  //     // console.log("resolverContract address:", resolverContract.address);
  //     // console.log("reNFTContract address: ", reNFTContract.address);

  //     for (let i = 0; i < 10; i++) {
  //       await e721Contract.connect(lender).award();
  //     }
  //     await e721Contract
  //       .connect(lender)
  //       .setApprovalForAll(reNFTContract.address, true);
  //     await e721Contract.connect(lender).approve(reNFTContract.address, 1);
  //   });
  //   const validateEvent = async (
  //     e: Event["args"],
  //     {
  //       nftAddress,
  //       tokenId,
  //       lendingId,
  //     }: {
  //       nftAddress: string;
  //       tokenId: number;
  //       lendingId: number;
  //     }
  //   ) => {
  //     if (!e) throw new Error("No args");
  //     expect(e.nftAddress).to.eq(nftAddress);
  //     expect(e.tokenId).to.eq(tokenId);
  //     expect(e.lendingId).to.eq(lendingId);
  //     expect(e.lenderAddress).to.eq(lender.address);
  //     expect(e.maxRentDuration).to.eq(MAX_RENT_DURATION);
  //     expect(e.dailyRentPrice).to.eq(DAILY_RENT_PRICE);
  //     expect(e.nftPrice).to.eq(NFT_PRICE);
  //     expect(e.paymentToken).to.eq(PAYMENT_TOKEN_BNB);
  //     switch (e.nftAddress.toLowerCase()) {
  //       case e721Contract.address.toLowerCase():
  //         expect(await e721Contract.ownerOf(tokenId)).to.eq(
  //           reNFTContract.address
  //         );
  //         break;
  //       default:
  //         throw new Error("unknown address");
  //     }
  //   };
  //   const lendBatch = async ({
  //     tokenIds,
  //     nftAddresses = Array(tokenIds.length).fill(e721Contract.address),
  //     maxRentDurations = Array(tokenIds.length).fill(MAX_RENT_DURATION),
  //     dailyRentPrices = Array(tokenIds.length).fill(DAILY_RENT_PRICE),
  //     nftPrices = Array(tokenIds.length).fill(NFT_PRICE),
  //     expectedLendingIds = tokenIds.map((_: any, ix: any) => ix + 1),
  //   }: lendArgs & {
  //     nftAddresses?: string[];
  //   }) => {
  //     const txn = await reNFTContract
  //       .connect(lender)
  //       .lend(
  //         nftAddresses,
  //         tokenIds,
  //         maxRentDurations,
  //         dailyRentPrices,
  //         nftPrices,
  //         Array(tokenIds.length).fill(PAYMENT_TOKEN_BNB)
  //       );

  //     const receipt = await txn.wait();
  //     const e = getEvents(receipt.events ?? [], "Lent");
  //     expect(e.length).to.eq(tokenIds.length);

  //     for (let i = 0; i < tokenIds.length; i++) {
  //       const ev = e[i].args;
  //       await validateEvent(ev, {
  //         nftAddress: nftAddresses[i],
  //         tokenId: tokenIds[i],
  //         lendingId: expectedLendingIds[i],
  //       });
  //     }
  //   };
  //   it("721", async function () {
  //     await lendBatch({ tokenIds: [1], expectedLendingIds: [1] });
  //   });
  //   it("721 and tokenIds[1, 2, 3]", async function () {
  //     await lendBatch({ tokenIds: [1, 2, 3,4,5,6]});
  //   });
  //   it("721 Lending dupplicate", async () => {
  //     await lendBatch({tokenIds: [1]});
  //     await expect(lendBatch({tokenIds: [1]})).to.be.reverted;
  //   })
  //   it("721 with 0 price", async () => {
  //     await expect(lendBatch({tokenIds:[1],dailyRentPrices:[packPrice(0)] ,nftPrices:[packPrice(0)]})).to.be.reverted;
  //   })
  // });
  context("Renting", function () {
    beforeEach(async function () {
      this.signers = await ethers.getSigners();
      owner = this.signers[0];
      lender = this.signers[1];
      renter = this.signers[2];
      fundWallet = this.signers[4];
      beneficiary = this.signers[5];
      this.BNB = await ethers.getContractFactory("BNB");
      this.E721 = await ethers.getContractFactory("E721");
      this.USDC = await ethers.getContractFactory("USDC");
      this.ReNFT = await ethers.getContractFactory("ReNFT");
      this.Resolver = await ethers.getContractFactory("Resolver");
      this.utils = await ethers.getContractFactory("Utils");
      bnbContract = await this.BNB.deploy(100000);
      e721Contract = await this.E721.deploy();
      Utils = await this.utils.deploy();
      usdcContract = await this.USDC.deploy(owner.address);
      resolverContract = await this.Resolver.deploy();
      reNFTContract = await this.ReNFT.deploy(
        beneficiary.address,
        0,
        resolverContract.address
      );
      // console.log("bnbContract address: ", bnbContract.address);
      // console.log("e721Contract address: ", e721Contract.address);
      // console.log("usdcContract address: ", usdcContract.address);
      // console.log("resolverContract address:", resolverContract.address);
      // console.log("reNFTContract address: ", reNFTContract.address);

      for (let i = 0; i < 10; i++) {
        await e721Contract.connect(lender).award();
      }
      await e721Contract
        .connect(lender)
        .setApprovalForAll(reNFTContract.address, true);
      await bnbContract.connect(renter).faucet();
      await bnbContract.connect(renter).approve(reNFTContract.address, ERC20_SEND_AMT );
    });
    const validateEvent = async (
      e: Event["args"],
      {
        nftAddress,
        tokenId,
        lendingId,
      }: {
        nftAddress: string;
        tokenId: number;
        lendingId: number;
      }
    ) => {
      if (!e) throw new Error("No args");
      expect(e.nftAddress).to.eq(nftAddress);
      expect(e.tokenId).to.eq(tokenId);
      expect(e.lendingId).to.eq(lendingId);
      expect(e.lenderAddress).to.eq(lender.address);
      expect(e.maxRentDuration).to.eq(MAX_RENT_DURATION);
      expect(e.dailyRentPrice).to.eq(DAILY_RENT_PRICE);
      expect(e.nftPrice).to.eq(NFT_PRICE);
      expect(e.paymentToken).to.eq(PAYMENT_TOKEN_BNB);
      switch (e.nftAddress.toLowerCase()) {
        case e721Contract.address.toLowerCase():
          expect(await e721Contract.ownerOf(tokenId)).to.eq(
            reNFTContract.address
          );
          break;
        default:
          throw new Error("unknown address");
      }
    };
    const lendBatch = async ({
      tokenIds,
      nftAddresses = Array(tokenIds.length).fill(e721Contract.address),
      maxRentDurations = Array(tokenIds.length).fill(MAX_RENT_DURATION),
      dailyRentPrices = Array(tokenIds.length).fill(DAILY_RENT_PRICE),
      nftPrices = Array(tokenIds.length).fill(NFT_PRICE),
      expectedLendingIds = tokenIds.map((_: any, ix: any) => ix + 1),
    }: lendArgs & {
      nftAddresses?: string[];
    }) => {
      return await reNFTContract
        .connect(lender)
        .lend(
          nftAddresses,
          tokenIds,
          maxRentDurations,
          dailyRentPrices,
          nftPrices,
          Array(tokenIds.length).fill(PAYMENT_TOKEN_BNB)
        );
    };

    it("rents ok - BNB- e721", async () => {
      const txn = await lendBatch({tokenIds: [1], maxRentDurations:[7]});
      let res = await txn.wait();
      console.log(res.events?.map(value => console.log(value.args)))
      const rentDurations = [2];
      // await lendBatch({tokenIds: [1], maxRentDurations:[7]});
      const tx = await reNFTContract.connect(renter).rent([e721Contract.address], [1], [1], rentDurations);

      // const balancesPre = await captureBalances([renter, reNFTContract], [bnbContract]);
      // expect(balancesPre[1]).to.be.eq(0);
      // const rentAmounts = BigNumber.from(rentDurations[0]).mul(
      //   await Utils.unpackPrice(DAILY_RENT_PRICE, DP18)
      // );
      // const pmtAmount = (await Utils.unpackPrice(NFT_PRICE, DP18)).add(
      //   rentAmounts
      // );
      // console.log(renter.address);
      // console.log(e721Contract.address);
      // console.log(await bnbContract.balanceOf(renter.address));
      // const tx = await reNFTContract.connect(renter).rent([e721Contract.address], [1], [1], rentDurations);

      // const balancesPost = await captureBalances([renter, reNFTContract], [bnbContract]);
      // expect(balancesPost[1]).to.be.equal(pmtAmount);
      // expect(balancesPost[0]).to.be.equal(balancesPre[0].sub(pmtAmount));
    })
  });
});
