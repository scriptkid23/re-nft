// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface INFTEpicWar is IERC721Upgradeable {
    function _exists(uint256 tokenId) external view returns (bool) ;
    function mintNft(address receiver, uint256 nftId) external;
}