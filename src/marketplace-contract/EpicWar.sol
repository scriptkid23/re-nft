//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 

contract EpicWar is ERC721URIStorage {
	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;
	address contractAddress;
	
	constructor(address marketPlaceAddress) ERC721("EpicWar Tokens", "EWAR") {
	    contractAddress = marketPlaceAddress;
	}
	
	function createToken(string memory tokenURI) public returns(uint256) {
	    _tokenIds.increment();
	    uint256 newItemId = _tokenIds.current();
	    _mint(msg.sender, newItemId);
	    _setTokenURI(newItemId, tokenURI);
	    // setApprovalForAll(contractAddress, true);
	    return newItemId;
	}
	
}