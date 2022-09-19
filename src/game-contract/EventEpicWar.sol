pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "./interface/IEventEpicWar.sol";
import "./TransferHelper.sol";
import "hardhat/console.sol";

contract EventEpicWar is
Initializable,
OwnableUpgradeable,
ERC165Upgradeable,
IEventEpicWar,
AccessControlUpgradeable,
ReentrancyGuardUpgradeable,
ERC721HolderUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address private EPIC_ERC20_ADDR;
    address public signer;
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    bytes32 public constant CLAIM_TOKEN_WITH_SIG_TYPEHASH =
    keccak256("TokenClaim(uint256 amount,uint256 nonce,uint256 deadline,string transactionId)");
    uint256 private spacerTime;
    mapping(address => uint256) public TokenClaimTimeStamp;

    mapping(address => uint256) public TokenClaimNonces;

    function __EventEpicWar_init(address _token)
    public
    initializer
    {
        // E0: addr err
        require(_token != address(0), "E0: token address must be set");
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OWNER_ROLE, _msgSender());
        EPIC_ERC20_ADDR = _token;
    }

    function _msgSender() internal view virtual override returns (address) {
        return msg.sender;
    }

    function _msgData()
    internal
    view
    virtual
    override
    returns (bytes calldata)
    {
        return msg.data;
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC165Upgradeable, AccessControlUpgradeable)
    returns (bool)
    {
        return
        interfaceId == type(IEventEpicWar).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function claimToken(
        uint256 amount,
        string calldata transactionId,
        EIP712Signature calldata _signature
    ) external nonReentrant {
        // E10: 0 amount
        require(amount > 0, "E10: amount invalid");

        // E11: transactionId empty
        require(bytes(transactionId).length > 0, "E11: transactionId null");

        // E12: transactionId not match signature
        require(keccak256(abi.encodePacked(transactionId)) == keccak256(abi.encodePacked(_signature.transactionId)), "E12: transactionId not match");

        // E5: Signature expired
        require(
            _signature.deadline == 0 || _signature.deadline >= block.timestamp,
            "E5: signature expired"
        );

        require(
            (TokenClaimTimeStamp[msg.sender] + spacerTime) <= block.timestamp,
            "E13: claim within spacer time"
        );
        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        CLAIM_TOKEN_WITH_SIG_TYPEHASH,
                        amount,
                        TokenClaimNonces[msg.sender]++,
                        _signature.deadline,
                        keccak256(abi.encodePacked(_signature.transactionId))
                    )
                )
            )
        );

        address recoveredAddress = ecrecover(
            digest,
            _signature.v,
            _signature.r,
            _signature.s
        );
        // E7: signature invalid
        require(recoveredAddress == signer, "E7: signature invalid");


        _handleOutgoingFund(_msgSender(), amount, EPIC_ERC20_ADDR);

        TokenClaimTimeStamp[msg.sender] = block.timestamp;

        emit TokenClaimed(
            transactionId,
            amount,
            _msgSender(),
            _signature.deadline
        );
    }

    // signing key does not require high security and can be put on an API server and rotated periodically, as signatures are issued dynamically
    function setSigner(address _signer) external onlyRole(OWNER_ROLE) {
        signer = _signer;
    }

    function setSpacer(uint256 spacer) external onlyRole(OWNER_ROLE) {
        spacerTime = spacer;
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return
        keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,address verifyingContract)"
                ),
                keccak256(bytes("EpicGame")),
                keccak256(bytes("1")),
                address(this)
            )
        );
    }

    function _handleOutgoingFund(
        address to,
        uint256 amount,
        address currency
    ) internal {
        if (currency == address(0)) {
            (bool isSuccess,) = to.call{value : amount}("");
            require(isSuccess, "Transfer failed: gas error");
        } else {
            IERC20Upgradeable(currency).safeTransfer(to, amount);
        }
    }
}
