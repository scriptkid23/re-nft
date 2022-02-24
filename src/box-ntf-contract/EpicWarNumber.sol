//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IEpicWarBox {
    function setRandomNumber(uint256 eventId, uint256 randomness) external;
}

contract EpicWarNumber is VRFConsumerBase, ConfirmedOwner(msg.sender), AccessControl {

    bytes32 private keyHash;
    uint256 private fee;
    address public boxContract;
    mapping(bytes32 => uint256) private reqToEvent;
    mapping(address => uint256) private eventToNumber;

    event RequestRandomNumber(bytes32 indexed requestId, uint256 indexed eventId);
    event ReceiveRandomNumber(bytes32 indexed requestId, uint256 indexed eventId, uint256 indexed result);


    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee, address _boxContract)
        VRFConsumerBase(_vrfCoordinator, _link)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        keyHash = _keyHash;
        fee = _fee;
        boxContract = _boxContract;
    }

    function getEventRandomNumber(uint256 _eventId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(LINK.balanceOf(address(this)) >= fee, "Contract not enough LINK to pay fee");
        bytes32 requestId = requestRandomness(keyHash, fee);
        reqToEvent[requestId] = _eventId;
        emit RequestRandomNumber(requestId, _eventId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 eventId = reqToEvent[requestId];
        IEpicWarBox(boxContract).setRandomNumber(eventId, randomness);
        emit ReceiveRandomNumber(requestId, eventId, randomness);
    }

    function withdrawLINK(address to, uint256 value) public onlyOwner {
        require(LINK.transfer(to, value), "Not enough LINK");
    }

    function setBoxContract(address _boxContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_boxContract != address(0) && _boxContract != msg.sender, "invalid address");
        revokeRole(DEFAULT_ADMIN_ROLE, boxContract);
        boxContract = _boxContract;
        _setupRole(DEFAULT_ADMIN_ROLE, _boxContract);
    }


    function setKeyHash(bytes32 _keyHash) public onlyOwner {
        keyHash = _keyHash;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function setAdminRole(address account) public onlyOwner {
        _setupRole(DEFAULT_ADMIN_ROLE, account);
    }

}
