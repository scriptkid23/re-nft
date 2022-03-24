pragma solidity ^0.8.0;

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
import "./interface/INFTEscrow.sol";
import "./interface/INFTEpicWar.sol";
import "./TransferHelper.sol";

contract NFTWEscrow is
  Initializable,
  OwnableUpgradeable,
  ERC165Upgradeable,
  INFTEscrow,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  ERC721HolderUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  address private EPIC_ERC20_ADDR;
  INFTEpicWar private EPIC_NFT_ADDR;
  address private signer;
  bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
  bytes32 public constant WITHDRAW_NFT_WITH_SIG_TYPEHASH =
    keccak256(
      "NftWithdrawal(uint256[] tokenIds,uint256 nonce,uint256 deadline)"
    );
  bytes32 public constant WITHDRAW_TOKEN_WITH_SIG_TYPEHASH =
    keccak256("TokenWithdrawal(uint256 amount,uint256 nonce,uint256 deadline)");
  mapping(address => uint256) public NFTWithDrawalNonces;
  mapping(address => uint256) public TokenWithDrawalNonces;
  mapping(uint256 => NFTInfo) public NftInfo;
  mapping(address => uint256) public TokenInfo;

  function __NFTWEscrow_init(address _token, address _nft) public initializer {
    require(_token != address(0), "E0"); // E0: addr err
    require(_nft != address(0), "E0");
    __Ownable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OWNER_ROLE, _msgSender());
    EPIC_ERC20_ADDR = _token;
    EPIC_NFT_ADDR = INFTEpicWar(_nft);
  }

  function _msgSender() internal view virtual override returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual override returns (bytes calldata) {
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
      interfaceId == type(INFTEscrow).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  function depositNft(uint256[] calldata tokenIds)
    external
    virtual
    nonReentrant
  {
    require(tokenIds.length > 0, "E1"); // E1: no NFT deposited
    for (uint256 i = 0; i < tokenIds.length; i++) {
      {
        uint256 tokenId = tokenIds[i];
        require(
          IERC721Upgradeable(EPIC_NFT_ADDR).ownerOf(tokenId) == _msgSender(),
          "E2"
        ); // E3: Not your token
        IERC721Upgradeable(EPIC_NFT_ADDR).safeTransferFrom(
          _msgSender(),
          address(this),
          tokenId
        );
        NftInfo[tokenId] = NFTInfo(_msgSender(), true);
      }
    }
    emit NFTDeposited(tokenIds, _msgSender());
  }

  function depositToken(uint256 amount, address currency)
    external
    virtual
    nonReentrant
  {
    require(EPIC_ERC20_ADDR != address(0), "E3"); // E3: Rewards token not set
    require(EPIC_ERC20_ADDR == currency, "E3");
    _handleIncomingFund(amount, currency);
    TokenInfo[_msgSender()] += amount;
    emit TokenDeposited(amount, _msgSender());
  }

  function nftWithdrawal(
    uint256[] calldata tokenIds,
    string calldata transactionId,
    EIP712Signature memory _signature
  ) external nonReentrant {
    require(tokenIds.length > 0, "E6"); // E6: empty token array
    require(
      _signature.deadline == 0 || _signature.deadline >= block.timestamp,
      "E5"
    ); // E5: Signature expired
    bytes32 domainSeparator = _calculateDomainSeparator();

    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        domainSeparator,
        keccak256(
          abi.encode(
            WITHDRAW_NFT_WITH_SIG_TYPEHASH,
            keccak256(abi.encodePacked(tokenIds)),
            NFTWithDrawalNonces[msg.sender]++,
            _signature.deadline
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
    require(recoveredAddress == signer, "E7"); // E7: signature invalid

    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      if (EPIC_NFT_ADDR.checkExistsToken(tokenId)) {
        require(NftInfo[tokenId].owner == _msgSender(), "E8"); // E8: Not your NFT
        require(NftInfo[tokenId].claimable, "E9"); // EB: not claimable
        EPIC_NFT_ADDR.safeTransferFrom(address(this), _msgSender(), tokenId);
        delete NftInfo[tokenId];
      } else {
        //mint function
        EPIC_NFT_ADDR.mintNft(msg.sender, tokenId);
      }
    }
    emit NFTWithdrawed(
      transactionId,
      tokenIds,
      _msgSender(),
      _signature.deadline
    );
  }

  function tokenWithdrawal(
    uint256 amount,
    string calldata transactionId,
    EIP712Signature calldata _signature
  ) external nonReentrant {
    require(amount > 0, "E10"); // E10: 0 amount
    require(
      _signature.deadline == 0 || _signature.deadline >= block.timestamp,
      "E5"
    ); // E5: Signature expired
    bytes32 domainSeparator = _calculateDomainSeparator();
    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        domainSeparator,
        keccak256(
          abi.encode(
            WITHDRAW_TOKEN_WITH_SIG_TYPEHASH,
            amount,
            TokenWithDrawalNonces[msg.sender]++,
            _signature.deadline
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

    require(recoveredAddress == signer, "E7"); // E7: signature invalid

    require(TokenInfo[_msgSender()] >= amount, "E11"); // E11: invalid amount
    uint256 remain = TokenInfo[_msgSender()] - amount;
    TokenInfo[_msgSender()] = remain;
    _handleOutgoingFund(_msgSender(), amount, EPIC_ERC20_ADDR);
    emit TokenWithdrawed(
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

  function _handleIncomingFund(uint256 amount, address currency) internal {
    if (currency == address(0)) {
      require(
        msg.value == amount,
        "Sent BNB Value does not match specified bid amount"
      );
      (bool isSuccess, ) = address(this).call{ value: msg.value }("");
      require(isSuccess, "Transfer failed: gas error");
    } else {
      IERC20Upgradeable token = IERC20Upgradeable(currency);
      uint256 beforeBalance = token.balanceOf(address(this));
      token.safeTransferFrom(msg.sender, address(this), amount);
      uint256 afterBalance = token.balanceOf(address(this));
      require(
        beforeBalance + amount == afterBalance,
        "Token transfer call did not transfer expected amount"
      );
    }
  }

  function _handleOutgoingFund(
    address to,
    uint256 amount,
    address currency
  ) internal {
    if (currency == address(0)) {
      (bool isSuccess, ) = to.call{ value: amount }("");
      require(isSuccess, "Transfer failed: gas error");
    } else {
      IERC20Upgradeable(currency).safeTransfer(to, amount);
    }
  }
}
