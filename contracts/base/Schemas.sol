//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "../interface/IResolver.sol";
struct Lending {
    address payable lender;
    uint8 maxRentDuration;
    bytes4 dailyRentPrice;
    bytes4 nftPrice;
    IResolver.PaymentToken paymentToken;
}
struct Renting {
    address payable renter;
    uint8 rentDuration;
    uint32 rentedAt;
}
struct LendingRenting {
    Lending lending;
    Renting renting;
}
struct CallData {
    address[] nfts;
    uint256[] tokenIds;
    uint8[] maxRentDurations;
    bytes4[] dailyRentPrices;
    bytes4[] nftPrices;
    uint256[] lendingIds;
    uint8[] rentDurations;
    IResolver.PaymentToken[] paymentTokens;
}
