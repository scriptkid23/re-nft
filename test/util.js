const { ethers } = require("hardhat");
const { BigNumber } =  require("ethers");
const { Block } = require("@ethersproject/abstract-provider");

const PRICE_BITSIZE = 32;

const decimalToPaddedHexString = (number,bitsize) => {
  const byteCount = Math.ceil(bitsize / 8);
  const maxBinValue = Math.pow(2, bitsize) - 1;
  /* In node.js this function fails for bitsize above 32 bits */
  if (bitsize > PRICE_BITSIZE) throw "number above maximum value";
  /* Conversion to unsigned form based on  */
  if (number < 0) number = maxBinValue + number + 1;
  return (
    "0x" +
    (number >>> 0)
      .toString(16)
      .toUpperCase()
      .padStart(byteCount * 2, "0")
  );
};

const advanceTime = async (seconds ) => {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
};

const getEvents = (events , name )  => {
  return events.filter((e) => e?.event?.toLowerCase() === name.toLowerCase());
};

// given the target price, give back the hex equivalent
const packPrice = (price)  => {
  if (price > 9999.9999) throw new Error("too high");

  const stringVersion = price.toString();
  const parts = stringVersion.split(".");
  let res;

  if (parts.length == 2) {
    const whole = parts[0];
    let decimal = parts[1];
    while (decimal.length < 4) {
      decimal += "0";
    }
    const wholeHex = decimalToPaddedHexString(Number(whole), 16);
    const decimalHex = decimalToPaddedHexString(Number(decimal), 16);
    const hexRepr = wholeHex.concat(decimalHex.slice(2));
    res = hexRepr;
  } else {
    if (parts.length != 1) throw new Error("price packing issue");
    const whole = parts[0];
    const wholeHex = decimalToPaddedHexString(Number(whole), 16);
    const decimalHex = "0000";
    res = wholeHex.concat(decimalHex);
  }
  return res;
};

const getBalance = async (address ) => {
  return await ethers.provider.getBalance(address);
};

const getErc20Balance = async (
  contract,
  balanceOf
) => {
  return await contract.balanceOf(balanceOf);
};

const takeFee = (rent, rentFee) =>
  rent.mul(rentFee).div(10_000);

const getLatestBlock = async () => {
  return await ethers.provider.getBlock("latest");
};

module.exports = {advanceTime, getEvents, packPrice, getBalance, getErc20Balance, takeFee, getLatestBlock}
