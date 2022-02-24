// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IMarketplace {
     enum MarketItemsType{AUCTION, LIST}
     struct MarketItem {
        uint256 tokenId;
        uint256 endTime;
        uint256 reservePrice;
        uint256 price;
        address tokenAddress;
        address tokenOwner;
        address bidder;
        address currency;
        MarketItemsType marketItemType;
       
    }

    struct Offer {
        // The offer currency
        address currency;
        // The offer price
        uint256 price;
    }
    
    event MarketItemCreated(
        uint256 indexed marketItemId,
        uint256 indexed tokenId,
        address indexed tokenAdress,
        uint256 duration,
        uint256 reservePrice,
        address tokenOwner,
        address auctionCurrency
    );
    
    
    event AuctionCanceled(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenAdress,
        address tokenOwner
    );
    
    event AuctionBidCanceled(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address sender,
        uint256 value
    );
    
    event AuctionBid(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address sender,
        uint256 value,
        bool firstBid
    );

    event TokenListed(
        uint256 indexed marketItemId, 
        address indexed tokenContract, 
        uint256 indexed tokenId, 
        address tokenOwner,
        address currency, 
        uint256 price
    );

    event TokenDelisted(
        uint256 indexed marketItemId,
        address indexed tokenContract, 
        uint256 indexed tokenId, 
        address tokenOwner
    );

    event TokenOffered(
        uint256 indexed marketItemId,
        address indexed tokenContract, 
        uint256 indexed tokenId,
        address buyer,
        address currency, 
        uint256 amount
    );

    event TokenBought(
        uint256 indexed marketItemId,
        uint256 indexed tokenId,
        uint256 price,
        address indexed tokenContract,
        address buyer,
        address seller,
        address currency  
    );

    event TokenOfferCanceled(
        uint256 indexed marketItemId,
        address indexed tokenContract, 
        uint256 indexed tokenId,
        address buyer
    );

    event TokenOfferTaken(
        uint256 indexed marketItemId, 
        uint256 indexed tokenId,
        uint256 amount,
        address indexed tokenContract,
        address seller,
        address buyer,
        address currency
       
    );

    event MarketItemEdited(
        uint256 indexed marketItemId,
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 price,
        address tokenOwner,
        address currency
    );
}