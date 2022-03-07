//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";
import "./interface/IMarketplace.sol";

contract Marketplace is Initializable, OwnableUpgradeable, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable, IMarketplace {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
        
    CountersUpgradeable.Counter private _marketIds;
    
    mapping(uint256 => MarketItem) public marketPlaceItems;

    mapping(address => mapping(address => uint256)) public floorPrices;

    mapping(address => mapping(uint256 => mapping(address => IMarketplace.Offer))) public itemOffers;
    
    address public vault;
    
    address public wethAddress;
    
    uint8 public minBidIncrementPerthousand;
    
    uint8 public feePerthousand;

   
    
    function __Marketplace_init(
        address _weth,
        address _vault
    ) public initializer {
        __Ownable_init();
        wethAddress = _weth;
        vault = _vault;
        minBidIncrementPerthousand = 50;
        feePerthousand = 10;
    }
    
    
    modifier marketItemExists(uint256 marketItemId) {
        require(marketPlaceItems[marketItemId].tokenOwner != address(0), "Item does not list in market");
        _;
    }

    function listItem(uint256 tokenId, address tokenAddress, uint256 price , address currency) external nonReentrant{
        require(price >= floorPrices[tokenAddress][currency],"Price cannot smaller that floor price");
        require( floorPrices[tokenAddress][currency] > 0 , "Token not allowed");
        address tokenOwner = IERC721Upgradeable(tokenAddress).ownerOf(tokenId);
        require(msg.sender == tokenOwner, "Must be token Owner");
        IERC721Upgradeable(tokenAddress).safeTransferFrom(tokenOwner, address(this), tokenId);
        _marketIds.increment();
        uint256 marketId = _marketIds.current();
        
        marketPlaceItems[marketId] = MarketItem ({
            tokenId: tokenId,
            endTime: 0,
            reservePrice: 0,
            price: price,
            tokenAddress: tokenAddress,
            tokenOwner: tokenOwner,
            bidder: address(0),
            currency: currency,
            marketItemType: MarketItemsType.LIST
        });
        emit TokenListed(marketId, tokenAddress, tokenId, tokenOwner, currency, price);

    }

    function delistItem(uint256 marketItemId) external marketItemExists(marketItemId){
        MarketItem storage listedItem = marketPlaceItems[marketItemId];
        require(listedItem.marketItemType == MarketItemsType.LIST, "Not a Listing item");
        require(listedItem.price > 0 , "Item not listed");
        require(msg.sender == listedItem.tokenOwner, "Not token owner");
        IERC721Upgradeable(listedItem.tokenAddress).safeTransferFrom(address(this), listedItem.tokenOwner, listedItem.tokenId);
        emit TokenDelisted(marketItemId, listedItem.tokenAddress, listedItem.tokenId, listedItem.tokenOwner);
        delete marketPlaceItems[marketItemId];
    }

    function buyItem(uint256 marketItemId, uint256 price, address currency) external payable nonReentrant marketItemExists(marketItemId){
        MarketItem storage listedItem = marketPlaceItems[marketItemId];
        address buyer = msg.sender;
        address tokenOwner = listedItem.tokenOwner;
        require(listedItem.marketItemType == MarketItemsType.LIST, "Not listed Item");
        require(currency == listedItem.currency, "Invalid currency");
        require(price > 0 && price == listedItem.price, "Invalid price");
        require(buyer != tokenOwner, "Token owner cannot buy");
        
        _handleIncomingFund(price, currency);
        uint256 fee = price * feePerthousand / 1000;
        _handleOutgoingFund(vault, fee, currency);

        uint256 sellerProfit = price - fee;
        _handleOutgoingFund(tokenOwner, sellerProfit, currency);
         IERC721Upgradeable(listedItem.tokenAddress).safeTransferFrom(address(this), buyer, listedItem.tokenId);
        Offer storage itemOffer = itemOffers[listedItem.tokenAddress][listedItem.tokenId][buyer];
        if (itemOffer.price > 0) {
            _handleOutgoingFund(buyer, itemOffer.price, itemOffer.currency);
            delete itemOffers[listedItem.tokenAddress][listedItem.tokenId][buyer];

            emit TokenOfferCanceled(marketItemId, listedItem.tokenAddress, listedItem.tokenId, buyer);
        }
        uint256 tokenId = listedItem.tokenId;
        delete marketPlaceItems[marketItemId];
        emit TokenBought(marketItemId, tokenId,  price, listedItem.tokenAddress, buyer, tokenOwner, currency);
    }


    function offer(uint256 marketItemId, uint256 tokenId, address tokenAddress, uint256 offerValue, address currency) external payable nonReentrant{
        require(floorPrices[tokenAddress][currency] > 0 , "Token not allowed");
        require(offerValue >= floorPrices[tokenAddress][currency], "Under floor price");
        
        address buyer = msg.sender;
        address tokenOwner = IERC721Upgradeable(tokenAddress).ownerOf(tokenId);
        require(buyer != tokenOwner, "Owner cannot make offer");
        Offer storage currentOffer = itemOffers[tokenAddress][tokenId][buyer];

        if (currency != currentOffer.currency && currentOffer.price > 0) {
            _handleOutgoingFund(buyer, currentOffer.price, currentOffer.currency);
            currentOffer.price = 0;
        }

        if (currency == currentOffer.currency) {
            require(offerValue != currentOffer.price, "Same offer");
        }

        bool needRefund = offerValue < currentOffer.price;

        uint256 requiredValue = needRefund ? currentOffer.price - offerValue : offerValue - currentOffer.price;
        if (needRefund) {
            _handleOutgoingFund(buyer, requiredValue, currentOffer.currency);
        } else {
            _handleIncomingFund(requiredValue, currency);
        }

        itemOffers[tokenAddress][tokenId][buyer] = Offer({
            currency: currency,
            price: offerValue

        });
        emit TokenOffered(marketItemId, tokenAddress, tokenId, buyer, currency, offerValue);
    }

    function takeOffer(uint256 marketItemId, uint256 tokenId, address tokenAddress, uint256 price, address currency, address buyer) external nonReentrant{
        MarketItem storage listedItem = marketPlaceItems[marketItemId];
        Offer storage itemOffer = itemOffers[tokenAddress][tokenId][buyer];
        address seller = msg.sender;
        address tokenOwner = IERC721Upgradeable(tokenAddress).ownerOf(tokenId);
        require(floorPrices[tokenAddress][currency] > 0 , "Token not allowed");
        require(currency == itemOffer.currency , "Invalid currency");
        require(price >= floorPrices[tokenAddress][currency] && price == itemOffer.price , "Invalid price");
        require(buyer != tokenOwner);
        if (marketItemId > 0) {
            require(seller == listedItem.tokenOwner, "Not market item owner");
        } else {
            require(seller == tokenOwner, "Not token owner");
        }
        
        uint256 fee = price * feePerthousand / 1000;
        _handleOutgoingFund(vault, fee, currency);

        uint256 sellerProfit = price - fee;

        _handleOutgoingFund(seller, sellerProfit, currency);

        IERC721Upgradeable(tokenAddress).safeTransferFrom(tokenOwner, buyer, tokenId);

        delete itemOffers[tokenAddress][tokenId][buyer];
        delete marketPlaceItems[marketItemId];

        emit TokenOfferTaken(marketItemId, tokenId, price, tokenAddress, seller, buyer, currency);
    }

    function cancelOffer(uint256 marketItemId, uint256 tokenId, address tokenAddress) external nonReentrant{
        address buyer = msg.sender;
        Offer storage itemOffer = itemOffers[tokenAddress][tokenId][buyer];
        require(itemOffer.price > 0 , "No offer");
        _handleOutgoingFund(buyer, itemOffer.price, itemOffer.currency);

        delete itemOffers[tokenAddress][tokenId][buyer];

        emit TokenOfferCanceled(marketItemId, tokenAddress, tokenId, buyer);
    }

    function setFloorPrice(address tokenAddress, address currency, uint256 floorPrice) external nonReentrant onlyOwner {
        floorPrices[tokenAddress][currency] = floorPrice;
    }

    
    function _handleOutgoingFund(address to, uint256 amount, address currency) internal {
        if(currency == address(0)) {
            (bool isSuccess,) = to.call{value: amount}("");
            require(isSuccess, "Transfer failed: gas error");
        } else {
            IERC20Upgradeable(currency).safeTransfer(to, amount);
        }
    }
    
    function _handleIncomingFund(uint256 amount, address currency) internal {
        if(currency == address(0)) {
            require(msg.value == amount, "Sent BNB Value does not match specified bid amount");
            (bool isSuccess,) = address(this).call{value: msg.value}("");
            require(isSuccess, "Transfer failed: gas error");
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(currency);
            uint256 beforeBalance = token.balanceOf(address(this));
            token.safeTransferFrom(msg.sender, address(this), amount);
            uint256 afterBalance = token.balanceOf(address(this));
            require(beforeBalance + amount == afterBalance, "Token transfer call did not transfer expected amount");
        }
    }

    function setFeePerthousand(uint8 _perthousand) external nonReentrant onlyOwner {
        require(_perthousand < 1000);
        feePerthousand = _perthousand;
    }

    function editPrice(uint256 marketItemId, uint256 _price) external nonReentrant marketItemExists(marketItemId){
        MarketItem storage listedItem = marketPlaceItems[marketItemId];
        require(msg.sender == listedItem.tokenOwner, "Not Owner");
        require(_price >= floorPrices[listedItem.tokenAddress][listedItem.currency],"Price cannot smaller that floor price");
        marketPlaceItems[marketItemId].price = _price;
        emit MarketItemEdited(marketItemId, listedItem.tokenId, listedItem.tokenAddress, listedItem.price, listedItem.tokenOwner, listedItem.currency);
    }

    receive() external payable {}
}
