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
import "./interface/IWETH.sol";
import "./interface/IMarketplace.sol";

contract MarketplaceAuction is Initializable, OwnableUpgradeable, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable, IMarketplace {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    
    bytes4 constant interfaceId = 0x80ac58cd; 
    
    CountersUpgradeable.Counter private _marketIds;
    
    mapping(uint256 => MarketItem) public marketPlaceItems;

    address public vault;
    
    address public wethAddress;
    
    uint8 public minBidIncrementPercentage;
    
    uint8 public feePercentage;

    function __MarketplaceAuction_init(
        address _weth,
        address _vault
    ) public initializer {
        __Ownable_init();
        wethAddress = _weth;
        vault = _vault;
        minBidIncrementPercentage = 5;
        feePercentage = 1;
    }

    modifier auctionExists(uint256 auctionId) {
        require(marketPlaceItems[auctionId].tokenOwner != address(0), "Auction doesn't exist");
        _;
    }

    function createAuction(uint256 tokenId, address tokenAddress, uint256 duration, uint256 reservePrice, address auctionCurrency) public nonReentrant returns (uint256) {  
        require(ERC165Upgradeable(tokenAddress).supportsInterface(interfaceId), "Token Contract not support ERC721");
        
        require(reservePrice > 0, "Reserve Price must not be 0");
        
        require(duration > 0, "Duration must not be 0");
        
        _marketIds.increment();
        address tokenOwner = IERC721Upgradeable(tokenAddress).ownerOf(tokenId);
        require(msg.sender == IERC721Upgradeable(tokenAddress).getApproved(tokenId) || msg.sender == tokenOwner, "caller must be approved or owner of nft");
        uint256 marketId = _marketIds.current();
        uint256 endTime = block.timestamp + duration;
        
        marketPlaceItems[marketId] = MarketItem ({
            tokenId: tokenId,
            endTime: endTime,
            reservePrice: reservePrice,
            price: 0,
            tokenAddress: tokenAddress,
            tokenOwner: tokenOwner,
            bidder: address(0),
            currency: auctionCurrency,
            marketItemType: MarketItemsType.AUCTION
        });
        
        IERC721Upgradeable(tokenAddress).safeTransferFrom(tokenOwner, address(this), tokenId);
        
        emit MarketItemCreated(
         marketId,
         tokenId,
         tokenAddress,
         duration,
         reservePrice,
         tokenOwner,
         auctionCurrency);
        return marketId;
        
    }

    function cancelAuction(uint256 auctionId) external nonReentrant auctionExists(auctionId) {
        require(marketPlaceItems[auctionId].tokenOwner == msg.sender, "Can only be cancelled by owner");
        
        require(marketPlaceItems[auctionId].price == 0, "Can not cancel once auction begin");

        require(marketPlaceItems[auctionId].marketItemType == MarketItemsType.AUCTION, "Can not cancel listed Item");
        
        address owner = marketPlaceItems[auctionId].tokenOwner;
        
        IERC721Upgradeable(marketPlaceItems[auctionId].tokenAddress).safeTransferFrom(address(this), owner, marketPlaceItems[auctionId].tokenId);
        delete marketPlaceItems[auctionId];
        emit AuctionCanceled(auctionId, marketPlaceItems[auctionId].tokenId, marketPlaceItems[auctionId].tokenAddress, owner);
        
    }
    
    function createBid(uint256 auctionId, uint256 price) external payable nonReentrant auctionExists(auctionId) {
        require(msg.sender == tx.origin, "Invalid bidder");
        require(marketPlaceItems[auctionId].endTime > block.timestamp, "Auction expired");
        require(marketPlaceItems[auctionId].marketItemType == MarketItemsType.AUCTION, "Can not bid on listed Item");
        bool firstBidder = true;
        require(marketPlaceItems[auctionId].reservePrice < price, "Bid price have to greater than reservePrice");
        require(price > marketPlaceItems[auctionId].price + (marketPlaceItems[auctionId].price * minBidIncrementPercentage /100), "Bid price have to greater than last bid by minBidIncrementPercentage");
        

        if(marketPlaceItems[auctionId].bidder != address(0)) {
            firstBidder = false;
            _handleOutgoingFund(marketPlaceItems[auctionId].bidder,marketPlaceItems[auctionId].price, marketPlaceItems[auctionId].currency);
            emit AuctionBidCanceled(auctionId, marketPlaceItems[auctionId].tokenId, marketPlaceItems[auctionId].tokenAddress, marketPlaceItems[auctionId].bidder, marketPlaceItems[auctionId].price);
        }
        _handleIncomingFund(price, marketPlaceItems[auctionId].currency);
        marketPlaceItems[auctionId].bidder = msg.sender;
        marketPlaceItems[auctionId].price = price;
        emit AuctionBid(auctionId, marketPlaceItems[auctionId].tokenId, marketPlaceItems[auctionId].tokenAddress, msg.sender, price, firstBidder);
    }
        function _handleOutgoingFund(address to, uint256 amount, address currency) internal {
        if(currency == address(0)) {
            IWETH(wethAddress).withdraw(amount);

            if(!_safeTransferETH(to, amount)) {
                IWETH(wethAddress).deposit{value: amount}();
                IERC20Upgradeable(wethAddress).safeTransfer(to, amount);
            }
        } else {
            IERC20Upgradeable(currency).safeTransfer(to, amount);
        }
    }
    
    function _handleIncomingFund(uint256 amount, address currency) internal {
        if(currency == address(0)) {
            require(msg.value == amount, "Sent BNB Value does not match specified bid amount");
            IWETH(wethAddress).deposit{value: amount}();
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(currency);
            uint256 beforeBalance = token.balanceOf(address(this));
            token.safeTransferFrom(msg.sender, address(this), amount);
            uint256 afterBalance = token.balanceOf(address(this));
            require(beforeBalance + amount == afterBalance, "Token transfer call did not transfer expected amount");
        }
    }
    
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{value: value}(new bytes(0));
        return success;
    }

    function setVault(address _vault) external nonReentrant onlyOwner {
        vault = _vault;
    }

    function setWeth(address _weth) external nonReentrant onlyOwner {
        wethAddress = _weth;
    }

    function setFeePercentage(uint8 _percentage) external nonReentrant onlyOwner {
        require(_percentage < 100);
        feePercentage = _percentage;
    }
}
