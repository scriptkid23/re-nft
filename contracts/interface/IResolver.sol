// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IResolver {
    enum PaymentToken {BNB, WETH, DAI, USDC, USDT, TUSD, RENT, BSC}

    function getPaymentToken(uint8 _pt) external view returns (address);

    function setPaymentToken(uint8 _pt, address _v) external;
}