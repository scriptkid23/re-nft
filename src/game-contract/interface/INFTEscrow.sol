pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface INFTEscrow {
  struct NFTInfo {
    //    uint16 weight;          // weight based on rarity
    address owner; // staked to, otherwise owner == 0
    bool claimable;
    //    uint16 deposit;         // unit is ether, paid in EPIC. The deposit is deducted from the last payment(s) since the deposit is non-custodial
    //    uint16 rentalPerDay;    // unit is ether, paid in EPIC. Total is deposit + rentalPerDay * days
    //    uint16 minRentDays;     // must rent for at least min rent days, otherwise deposit is forfeited up to this amount
    //    uint32 rentableUntil;   // timestamp in unix epoch
  }

  struct EIP712Signature {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  event NFTDeposited(uint256[] tokenIds, address indexed user);
  event NFTWithdrawed(
    string transactionId,
    uint256[] tokenIds,
    address indexed user,
    uint256 deadline
  );
  event TokenDeposited(uint256 amount, address indexed user);
  event TokenWithdrawed(
    string transactionId,
    uint256 amount,
    address indexed user,
    uint256 deadline
  );
}
