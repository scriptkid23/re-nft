//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract EpicWarNFT is Initializable, OwnableUpgradeable, ERC721EnumerableUpgradeable, ERC721HolderUpgradeable, AccessControlUpgradeable {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    string public baseURI;
    
    mapping(uint256 => bool) public blackList;

    event NFTCreated(string baseURI, uint256 indexed id, address minter);
    event BanNft(uint256 indexed id);
    event UnbanNft(uint256 indexed id);

    function __EpicWarNFT_init(
        string memory _name,
        string memory _symbol,
        string memory _baseUri
    ) public initializer {
        __Ownable_init();
        ERC721Upgradeable.__ERC721_init(_name, _symbol);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        baseURI = _baseUri;
    }

    function mintNft(address receiver, uint256 nftId) onlyRole(MINTER_ROLE) external {
        _safeMint(receiver, nftId);
        emit NFTCreated(baseURI, nftId, receiver);
    }

    function grantMinterRole(address account) onlyRole(DEFAULT_ADMIN_ROLE) external {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) onlyRole(DEFAULT_ADMIN_ROLE) external {
        revokeRole(MINTER_ROLE, account);
    }

    function banNft(uint256 nftId) onlyRole(DEFAULT_ADMIN_ROLE) external {
        blackList[nftId] = true;
        emit BanNft(nftId);
    }

    function unbanNft(uint256 nftId) onlyRole(DEFAULT_ADMIN_ROLE) external {
        delete blackList[nftId];
        emit UnbanNft(nftId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(blackList[tokenId] != true, "Nft banned");

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function setBaseURI(string memory uri) onlyRole(DEFAULT_ADMIN_ROLE) external {
        baseURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
    
    function checkExistsToken(uint256 tokenId) external view returns (bool) {
        return super._exists(tokenId);
    }
}