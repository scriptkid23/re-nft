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

import "hardhat/console.sol";

interface IEpicWarNumber {
    function getEventRandomNumber(uint256 eventId) external;
}

interface IEpicWarNFT {
    function mintNft(address receiver, uint256 nftId) external;
}


contract EpicWarBox is Initializable, OwnableUpgradeable, ERC721EnumerableUpgradeable, ERC721HolderUpgradeable {
    struct EventInfo {
        uint256 totalSupply;
        uint256 boxPrice;
        address currency;
        uint256 startTime;
        uint256 endTime;
        uint256 maxBuy;
        uint256 startID;
        uint256 openBoxTime;
        address nftContract;
        string eventType;
        uint256 boxCount;
    }

    struct BoxList {
        uint256 quantity;
        uint256 bought;
        string nameBox;
        string uriImage;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => EventInfo) public eventByID; //event info by ID
    mapping(uint256 => mapping(uint256 => BoxList)) public boxesByEvent; //list box in event & index
    mapping(uint256 => uint256) public boxByEvent; //check box in event
    mapping(uint256 => mapping(address => uint256)) public userBought; //number of box buy in event
    mapping(uint256 => uint256) public randomNumber; //random number by event


    string public uri;
    address public signer;
    address public fundWallet;
    address public VRFContract;
    bool public allowTransfer;
    
    event EventCreated(uint256 totalSupply, uint256 price, address currency, uint256 startTime, uint256 endTime, uint256 maxBuy, uint256 startID, uint256 openBoxTime, address nftContract);
    event BoxCreated(uint256 indexed id, address boxOwner, uint256 eventId, string eventType, string boxUri, string boxName, address boxContractAddress, uint256 price, address currency);
    event BoxOpened(address indexed user, uint256 boxId, uint256 nftId, uint256 eventId);
    
    function __EpicWarBox_init(
        string memory name,
        string memory symbol,
        string memory _uri,
        address _signer,
        address _fundWallet,
        address _VRFContract
    ) public initializer {
        __Ownable_init();
        ERC721Upgradeable.__ERC721_init(name, symbol);

        uri = _uri;
        signer = _signer;
        fundWallet = _fundWallet;
        VRFContract = _VRFContract;
        allowTransfer = false;
    }

    function createEvent(
        uint256 _eventID,
        string memory _eventType,
        uint256 _totalSupply,
        uint256 _price,
        address _currency,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxBuy,
        uint256 _startID,
        uint256 _openBoxTime,
        address _nftContract
    ) external onlyOwner {
        require(_totalSupply > 0, "Invalid Supply");
        require(_startTime < _endTime, "Invalid time");
        require(_maxBuy > 0, "Need set max buy");

        eventByID[_eventID] = EventInfo(_totalSupply, _price, _currency, _startTime, _endTime, _maxBuy, _startID, _openBoxTime, _nftContract, _eventType, 0);
        emit EventCreated(
            _totalSupply,
            _price, _currency,
            _startTime, _endTime,
            _maxBuy,
            _startID,
            _openBoxTime,
            _nftContract
        );
    }
    
    function addBox(
        uint256 _eventID,
        uint256[] memory _quantity,
        string[] memory _boxName,
        string[] memory _boxImageUri
    ) public onlyOwner {
        require(_quantity.length == _boxName.length && _boxName.length == _boxImageUri.length, "Box data error");
        for (uint256 index = 0; index < _quantity.length; index++) {

            boxesByEvent[_eventID][index] = BoxList(_quantity[index], 0, _boxName[index], _boxImageUri[index]);
        }
    }


    function buyBox(uint256 _eventID, uint256 _amount, uint256 _indexBoxList, address _token) public payable {
        EventInfo storage eventInfo = eventByID[_eventID];

        require(_amount > 0 && _amount + userBought[_eventID][msg.sender] <= eventInfo.maxBuy, "Rate limit exceeded");
        require(block.timestamp >= eventInfo.startTime, "Sale has not started");
        require(block.timestamp <= eventInfo.endTime, "Sale has ended");
        require(_token == eventInfo.currency, "Invalid token");
        BoxList storage boxes = boxesByEvent[_eventID][_indexBoxList];

        require(boxes.quantity - boxes.bought >= _amount, "sold out");
        
        uint256 totalFund = eventInfo.boxPrice * _amount;
        if (_token == address(0)) {
            require(totalFund == msg.value, "invalid value");
        }
        
        _fowardFund(totalFund, _token);
        for (uint i = 0; i < _amount; i++) {
            uint256 boxID = eventInfo.boxCount + eventInfo.startID + 1;
            _safeMint(msg.sender, boxID);
            boxByEvent[boxID] = _eventID;
            userBought[_eventID][msg.sender] += 1;
            eventInfo.boxCount += 1;
            emit BoxCreated(boxID, msg.sender, _eventID, eventInfo.eventType, boxes.uriImage, boxes.nameBox, address(this), eventInfo.boxPrice, eventInfo.currency);
        }

        boxes.bought += _amount;
    }

    function _fowardFund(uint256 _amount, address _token) internal {
        if (_token == address(0)) { // native token (BNB)
            (bool isSuccess,) = fundWallet.call{value: _amount}("");
            require(isSuccess, "Transfer failed: gas error");
            return;
        }

        IERC20(_token).transferFrom(msg.sender, fundWallet, _amount);
    }

    function setAllowTransfer(bool allow) public onlyOwner {
        allowTransfer = allow;
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            require(allowTransfer, "Box is not allowed to transfer");
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function updateOpenBoxInfo(uint256 _eventID, uint256 _openBoxTime, address _nftContract) public onlyOwner {
        EventInfo storage eventInfo = eventByID[_eventID];
        eventInfo.openBoxTime = _openBoxTime;
        eventInfo.nftContract = _nftContract;
    }

    function updateEventTimeInfo(uint256 _eventID, uint256 _startTime, uint256 _endTime) public onlyOwner {
        require(_startTime < _endTime, "Invalid time");
        EventInfo storage eventInfo = eventByID[_eventID];
        eventInfo.startTime = _startTime;
        eventInfo.endTime = _endTime;
    }

    function updateEventPriceInfo(uint256 _eventID, uint256 _price, address _currency) public onlyOwner {
        EventInfo storage eventInfo = eventByID[_eventID];
        eventInfo.boxPrice = _price;
        eventInfo.currency = _currency;
    }

    function updateEventTotalSupplyInfo(uint256 _eventID, uint256 _totalSupply, uint256 _startID, uint256 _maxBuy) public onlyOwner {
        EventInfo storage eventInfo = eventByID[_eventID];
        eventInfo.totalSupply = _totalSupply;
        eventInfo.startID = _startID;
        eventInfo.maxBuy = _maxBuy;
    }

    function updateBoxEventCount(uint256 _eventID, uint256 _count) public onlyOwner {
        EventInfo storage eventInfo = eventByID[_eventID];
        eventInfo.boxCount = _count;
    }

    function requestRandomNumber(uint256 _eventID) public onlyOwner {
        IEpicWarNumber(VRFContract).getEventRandomNumber(_eventID);
    }

    function setRandomNumber(uint256 _eventID, uint256 _randomness) external {
        require(msg.sender == VRFContract, "VRFContract invalid");
        randomNumber[_eventID] = _randomness;
    }

    function setFundWallet(address _fund) public onlyOwner {
        fundWallet = _fund;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        uri = baseURI;
    }

    function setVRFContract(address _VRFContract) public onlyOwner {
        require(_VRFContract != address(0), "Invalid contract");
        VRFContract = _VRFContract;
    }

    // Open box
    function openBox(uint256 _boxId, uint256 _eventID) public {
        require(boxByEvent[_boxId] == _eventID, "Box not in event");
        EventInfo storage eventInfo = eventByID[_eventID];
        require(ownerOf(_boxId) == msg.sender, "User must be owner of boxId");
        require(block.timestamp >= eventInfo.openBoxTime, "Open box has not started");
        uint256 rand = randomNumber[_eventID] % eventInfo.totalSupply;
        uint256 nftId = (_boxId + rand) % eventInfo.totalSupply + eventInfo.startID; //random boxId to nftId

        //mint nft from nft contract & burn box nft
        IEpicWarNFT(eventInfo.nftContract).mintNft(msg.sender, nftId);
        _burn(_boxId);
        emit BoxOpened(msg.sender, _boxId, nftId, _eventID);
    }

    function emergencyWithdrawNFT(uint256 _eventID, uint256 _id, address _to) public onlyOwner {
        // transfer NFT from owner
        EventInfo storage eventInfo = eventByID[_eventID];
        IERC721(eventInfo.nftContract).safeTransferFrom(address(this), _to, _id);
    }

    function openAllBox(uint256 _eventID) public {
        uint256 userBox = balanceOf(msg.sender);
        require(userBox > 0, "User not owner of any box");
        for (uint256 index = 0; index < userBox; index++) {
            uint256 currentBalance = balanceOf(msg.sender);
            if (currentBalance == 0) {
                continue;
            }
            uint256 boxId = tokenOfOwnerByIndex(msg.sender, currentBalance - 1);
            if (boxByEvent[boxId] == _eventID) {
                openBox(boxId, _eventID);
            }
        }
    }
}