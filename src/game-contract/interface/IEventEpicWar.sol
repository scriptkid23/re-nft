pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IEventEpicWar {
    struct EIP712Signature {
        uint256 deadline;
        string transactionId;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    event TokenClaimed(
        string transactionId,
        uint256 amount,
        address indexed user,
        uint256 deadline
    );
}
