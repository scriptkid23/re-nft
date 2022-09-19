pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
FOR TEST ONLY
*/
contract EpicWarNFTTest is ERC721URIStorage,Initializable, OwnableUpgradeable, AccessControlUpgradeable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address contractAddress;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view override(Context, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }

    constructor(address marketPlaceAddress) ERC721("EpicWar NFT", "EWAR-NFT") {
        contractAddress = marketPlaceAddress;
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function checkExistsToken(uint256 tokenId) external view returns (bool) {
        return super._exists(tokenId);
    }

    function mintNft(address receiver, uint256 nftId) onlyRole(MINTER_ROLE) external {
        _safeMint(receiver, nftId);
    }

    function grantMinterRole(address account) onlyRole(DEFAULT_ADMIN_ROLE) external {
        grantRole(MINTER_ROLE, account);
    }

    function createToken(string memory tokenURI) onlyRole(MINTER_ROLE) public returns(uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        return newItemId;
    }

}