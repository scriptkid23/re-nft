//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "../interface/IResolver.sol";
struct Lending {
    address payable lender;
    uint8 maxRentDuration;
    bytes4 dailyRentPrice;
    bytes4 nftPrice;
    uint8 lentAmount;
    IResolver.PaymentToken paymentToken;
}
struct Renting {
    address payable renter;
    uint8 rentDuration;
    uint32 rentedAt;
}
struct LendingRenting {
    Lending lending;
    Renting rending;
}


