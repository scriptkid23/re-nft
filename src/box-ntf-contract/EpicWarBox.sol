//SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";

interface IEpicWarNumber {
  function getEventRandomNumber(uint16 eventId) external;
}

interface IEpicWarNFT {
  function mintNft(address receiver, uint256 nftId) external;
}

contract EpicWarBox is
  Initializable,
  OwnableUpgradeable,
  ERC721EnumerableUpgradeable,
  ERC721HolderUpgradeable,
  ReentrancyGuardUpgradeable
{
  struct EventInfo {
    uint16 totalSupply;
    uint256 boxPrice;
    address currency;
    uint256 startTime;
    uint256 endTime;
    uint16 maxBuy;
    uint256 startID;
    uint256 openBoxTime;
    address nftContract;
    string eventType;
    uint16 boxCount;
  }

  struct BoxList {
    uint16 quantity;
    uint16 bought;
    string nameBox;
    string uriImage;
  }

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  mapping(uint16 => EventInfo) public eventByID; //event info by ID
  mapping(uint16 => uint16[]) private ranIDByEvent; //random array by event ID
  mapping(uint16 => mapping(uint16 => BoxList)) public boxesByEvent; //list box in event & index
  mapping(uint256 => uint16) public boxByEvent; //check box in event
  mapping(uint16 => mapping(address => uint16)) public userBought; //number of box buy in event
  mapping(uint16 => uint256) public randomNumber; //random number by event

  string public uri;
  address public fundWallet;
  address public VRFContract;
  bool public allowTransfer;
  uint256 public eventStartId;

  event EventCreated(
    uint16 totalSupply,
    uint256 price,
    address currency,
    uint256 startTime,
    uint256 endTime,
    uint16 maxBuy,
    uint256 startID,
    uint256 openBoxTime,
    address nftContract
  );
  event BoxCreated(
    uint256 indexed id,
    address boxOwner,
    uint16 eventId,
    string eventType,
    string boxUri,
    string boxName,
    address boxContractAddress,
    uint256 price,
    address currency
  );
  event BoxOpened(
    address indexed user,
    uint256 boxId,
    uint256 nftId,
    uint16 eventId
  );

  function __EpicWarBox_init(
    string memory name,
    string memory symbol,
    string memory _uri,
    address _fundWallet,
    address _VRFContract
  ) public initializer {
    __Ownable_init();
    ERC721Upgradeable.__ERC721_init(name, symbol);

    uri = _uri;
    fundWallet = _fundWallet;
    VRFContract = _VRFContract;
    allowTransfer = false;
    eventStartId = 0;
  }

  function createEvent(
    uint16 _eventID,
    string calldata _eventType,
    uint16 _totalSupply,
    uint256 _price,
    address _currency,
    uint256 _startTime,
    uint256 _endTime,
    uint16 _maxBuy,
    uint256 _openBoxTime,
    address _nftContract
  ) external onlyOwner {
    require(_totalSupply > 0, "Invalid Supply");
    require(_startTime < _endTime, "Invalid time");
    require(_maxBuy > 0, "Need set max buy");

    eventByID[_eventID] = EventInfo(
      _totalSupply,
      _price,
      _currency,
      _startTime,
      _endTime,
      _maxBuy,
      eventStartId,
      _openBoxTime,
      _nftContract,
      _eventType,
      0
    );
    eventStartId += _totalSupply;

    emit EventCreated(
      _totalSupply,
      _price,
      _currency,
      _startTime,
      _endTime,
      _maxBuy,
      eventStartId,
      _openBoxTime,
      _nftContract
    );
  }

  function addBoxID(uint16 _eventID, uint16[] calldata _boxIDList)
    public
    onlyOwner
  {
    EventInfo storage eventInfo = eventByID[_eventID];
    require(
      _boxIDList.length == eventInfo.totalSupply,
      "Box list not equal total supply"
    );

    ranIDByEvent[_eventID] = _boxIDList;
  }

  function getBoxID(uint16 _eventID)
    public
    view
    onlyOwner
    returns (uint16[] memory)
  {
    return ranIDByEvent[_eventID];
  }

  function addBox(
    uint16 _eventID,
    uint16[] calldata _quantity,
    string[] calldata _boxName,
    string[] calldata _boxImageUri
  ) public onlyOwner {
    require(
      _quantity.length == _boxName.length &&
        _boxName.length == _boxImageUri.length,
      "Box data error"
    );
    uint16 numBox = 0;
    for (uint16 index = 0; index < _quantity.length; index++) {
      numBox += _quantity[index];
    }
    EventInfo storage eventInfo = eventByID[_eventID];
    require(numBox == eventInfo.totalSupply, "Quantity not equal total supply");
    for (uint16 index = 0; index < _quantity.length; index++) {
      boxesByEvent[_eventID][index] = BoxList(
        _quantity[index],
        0,
        _boxName[index],
        _boxImageUri[index]
      );
    }
  }

  function buyBox(
    uint16 _eventID,
    uint16 _amount,
    uint16 _indexBoxList,
    address _token
  ) public payable nonReentrant {
    EventInfo storage eventInfo = eventByID[_eventID];

    require(
      _amount > 0 &&
        _amount + userBought[_eventID][msg.sender] <= eventInfo.maxBuy,
      "Rate limit exceeded"
    );

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
    for (uint16 i = 0; i < _amount; i++) {
      uint256 boxID = uint256(eventInfo.boxCount) + eventInfo.startID + 1;
      _safeMint(msg.sender, boxID);
      boxByEvent[boxID] = _eventID;
      userBought[_eventID][msg.sender] += 1;
      eventInfo.boxCount += 1;
      emit BoxCreated(
        boxID,
        msg.sender,
        _eventID,
        eventInfo.eventType,
        boxes.uriImage,
        boxes.nameBox,
        address(this),
        eventInfo.boxPrice,
        eventInfo.currency
      );
    }

    boxes.bought += _amount;
  }

  function mintBox(
    uint16 _eventID,
    address[] calldata _adds,
    uint16 _indexBoxList
  ) public onlyOwner nonReentrant {
    EventInfo storage eventInfo = eventByID[_eventID];

    BoxList storage boxes = boxesByEvent[_eventID][_indexBoxList];

    require(boxes.quantity - boxes.bought >= _adds.length, "sold out");

    for (uint16 i = 0; i < _adds.length; i++) {
      uint256 boxID = uint256(eventInfo.boxCount) + eventInfo.startID + 1;
      _safeMint(_adds[i], boxID);
      boxByEvent[boxID] = _eventID;
      userBought[_eventID][_adds[i]] += 1;
      eventInfo.boxCount += 1;
      emit BoxCreated(
        boxID,
        _adds[i],
        _eventID,
        eventInfo.eventType,
        boxes.uriImage,
        boxes.nameBox,
        address(this),
        eventInfo.boxPrice,
        eventInfo.currency
      );
    }
    boxes.bought += uint16(_adds.length);
  }

  function _fowardFund(uint256 _amount, address _token) internal {
    if (_token == address(0)) {
      // native token (BNB)
      (bool isSuccess, ) = fundWallet.call{ value: _amount }("");
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

  function updateOpenBoxInfo(
    uint16 _eventID,
    uint256 _openBoxTime,
    address _nftContract
  ) public onlyOwner {
    EventInfo storage eventInfo = eventByID[_eventID];
    eventInfo.openBoxTime = _openBoxTime;
    eventInfo.nftContract = _nftContract;
  }

  function updateEventTimeInfo(
    uint16 _eventID,
    uint256 _startTime,
    uint256 _endTime
  ) public onlyOwner {
    require(_startTime < _endTime, "Invalid time");
    EventInfo storage eventInfo = eventByID[_eventID];
    eventInfo.startTime = _startTime;
    eventInfo.endTime = _endTime;
  }

  function updateEventPriceInfo(
    uint16 _eventID,
    uint256 _price,
    address _currency
  ) public onlyOwner {
    EventInfo storage eventInfo = eventByID[_eventID];
    eventInfo.boxPrice = _price;
    eventInfo.currency = _currency;
  }

  function updateEventTotalSupplyInfo(
    uint16 _eventID,
    uint16 _totalSupply,
    uint256 _startID,
    uint16 _maxBuy
  ) public onlyOwner {
    EventInfo storage eventInfo = eventByID[_eventID];
    eventInfo.totalSupply = _totalSupply;
    eventInfo.startID = _startID;
    eventInfo.maxBuy = _maxBuy;
  }

  function updateBoxEventCount(uint16 _eventID, uint16 _count)
    public
    onlyOwner
  {
    EventInfo storage eventInfo = eventByID[_eventID];
    eventInfo.boxCount = _count;
  }

  function setBaseURI(string memory _uri) external onlyOwner {
    uri = _uri;
  }

  function _baseURI() internal view override returns (string memory) {
    return uri;
  }

  function requestRandomNumber(uint16 _eventID) public onlyOwner {
    EventInfo storage eventInfo = eventByID[_eventID];
    require(eventInfo.openBoxTime > block.timestamp, "Open box has started");
    IEpicWarNumber(VRFContract).getEventRandomNumber(_eventID);
  }

  function setRandomNumber(uint16 _eventID, uint256 _randomness) external {
    require(msg.sender == VRFContract, "VRFContract invalid");
    randomNumber[_eventID] = _randomness;
  }

  function setFundWallet(address _fund) public onlyOwner {
    fundWallet = _fund;
  }

  function setVRFContract(address _VRFContract) public onlyOwner {
    require(_VRFContract != address(0), "Invalid contract");
    VRFContract = _VRFContract;
  }

  //call when create new event after mint nft from game to update eventStartId
  function setEventStartId(uint256 _startId) public onlyOwner {
    eventStartId = _startId;
  }

  // Open box
  function openBox(uint256 _boxId, uint16 _eventID) public {
    require(boxByEvent[_boxId] == _eventID, "Box not in event");
    EventInfo storage eventInfo = eventByID[_eventID];
    require(ownerOf(_boxId) == msg.sender, "User must be owner of box!");
    require(
      block.timestamp >= eventInfo.openBoxTime,
      "Open box has not started"
    );
    uint256 rand = randomNumber[_eventID] % eventInfo.totalSupply;
    uint256 nftId = ((_boxId + rand) % eventInfo.totalSupply); //random boxId to nftId
    uint16[] memory randBoxList = ranIDByEvent[_eventID];
    //mint nft from nft contract & burn box nft
    IEpicWarNFT(eventInfo.nftContract).mintNft(
      msg.sender,
      randBoxList[nftId] + eventInfo.startID
    );
    _burn(_boxId);
    emit BoxOpened(
      msg.sender,
      _boxId,
      randBoxList[nftId] + eventInfo.startID,
      _eventID
    );
  }

  function emergencyWithdrawNFT(
    uint16 _eventID,
    uint256 _id,
    address _to
  ) public onlyOwner nonReentrant {
    // transfer NFT from owner
    EventInfo storage eventInfo = eventByID[_eventID];
    IERC721(eventInfo.nftContract).safeTransferFrom(address(this), _to, _id);
  }

  function openSelectedBox(uint256[] calldata nftIds) public nonReentrant {
    require(nftIds.length > 0, "Not open any box?");
    for (uint256 index = 0; index < nftIds.length; index++) {
      require(
        ownerOf(nftIds[index]) == msg.sender,
        "User must be owner of box!"
      );
      openBox(nftIds[index], boxByEvent[nftIds[index]]);
    }
  }

  function openAllBox() public nonReentrant {
    uint256 userBox = balanceOf(msg.sender);
    require(userBox > 0, "User not owner of any box");
    for (uint256 index = 0; index < userBox; index++) {
      uint256 boxId = tokenOfOwnerByIndex(msg.sender, 0);
      openBox(boxId, boxByEvent[boxId]);
    }
  }
}
