//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./interface/IReNFT.sol";
import "./interface/IResolver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./base/Schemas.sol";

contract ReNFT is IReNft, ERC721Holder, Ownable, Pausable {
    using SafeERC20 for ERC20;
    IResolver private resolver;

    uint256 public rentFee = 0;
    uint256 private lendingId = 1;
    uint256 private constant SECONDS_IN_DAY = 86400;

    mapping(bytes32 => LendingRenting) private lendingRenting;

    function ensureIsNotZeroAddr(address _addr) private pure {
        require(_addr != address(0), "ReNFT::zero address");
    }

    // Util function
    function is721(address _nft) private view returns (bool) {
        return IERC165(_nft).supportsInterface(type(IERC721).interfaceId);
    }

    function ensureIsZeroAddr(address _addr) private pure {
        require(_addr == address(0), "ReNFT::not a zero address");
    }

    function ensureIsNull(Lending memory _lending) private pure {
        ensureIsZeroAddr(_lending.lender);
        require(_lending.maxRentDuration == 0, "ReNFT::duration not zero");
        require(_lending.dailyRentPrice == 0, "ReNFT::rent price not zero");
        require(_lending.nftPrice == 0, "ReNFT::nft price not zero");
    }

    function ensureIsNotNull(Lending memory _lending) private pure {
        ensureIsNotZeroAddr(_lending.lender);
        require(_lending.maxRentDuration != 0, "ReNFT::duration zero");
        require(_lending.dailyRentPrice != 0, "ReNFT::rent price is zero");
        require(_lending.nftPrice != 0, "ReNFT::nft price is zero");
    }

    function ensureIsNull(Renting memory _renting) private pure {
        ensureIsZeroAddr(_renting.renter);
        require(_renting.rentDuration == 0, "ReNFT::duration not zero");
        require(_renting.rentedAt == 0, "ReNFT::rented at not zero");
    }

    function ensureIsNotNull(Renting memory _renting) private pure {
        ensureIsNotZeroAddr(_renting.renter);
        require(_renting.rentDuration != 0, "ReNFT::duration is zero");
        require(_renting.rentedAt != 0, "ReNFT::rented at is zero");
    }

    function ensureTokenNotSentinel(uint8 _paymentIx) private pure {
        require(_paymentIx > 0, "ReNFT::token is sentinel");
    }

    function ensureIsLendable(
        uint8 _maxRentDuration,
        bytes4 _dailyRentPrice,
        bytes4 _nftPrice
    ) private pure {
        require(_maxRentDuration > 0, "ReNFT::duration is zero");
        require(_maxRentDuration <= type(uint8).max, "ReNFT::not uint8");
        require(uint32(_dailyRentPrice) > 0, "ReNFT::rent price is zero");
        require(uint32(_nftPrice) > 0, "ReNFT::nft price is zero");
    }

    function ensureIsUnpackablePrice(bytes4 _price, uint256 _scale)
        private
        pure
    {
        require(uint32(_price) > 0, "ReNFT::invalid price");
        require(_scale >= 10000, "ReNFT::invalid scale");
    }

    function ensureIsRentable(
        Lending memory _lending,
        uint8 _rentDuration,
        address _msgSender
    ) private pure {
        require(_msgSender != _lending.lender, "ReNFT::cant rent own nft");
        require(_rentDuration <= type(uint8).max, "ReNFT::not uint8");
        require(_rentDuration > 0, "ReNFT::duration is zero");
        require(
            _rentDuration <= _lending.maxRentDuration,
            "ReNFT::exceeds allowed max"
        );
    }

    function unpackPrice(bytes4 _price, uint256 _scale)
        private
        pure
        returns (uint256)
    {
        ensureIsUnpackablePrice(_price, _scale);

        uint16 whole = uint16(bytes2(_price));
        uint16 decimal = uint16(bytes2(_price << 16));
        uint256 decimalScale = _scale / 10000;
        // check large than 4 bytes
        if (whole > 9999) {
            whole = 9999;
        }
        if (decimal > 9999) {
            decimal = 9999;
        }

        uint256 w = whole * _scale;
        uint256 d = decimal * decimalScale;
        uint256 price = w + d;

        return price;
    }

    // TODO: create function lending
    function lend(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint8[] memory _maxRentDurations,
        bytes4[] memory _dailyRentPrices,
        bytes4[] memory _nftPrices,
        IResolver.PaymentToken[] memory _paymentTokens
    ) external override whenNotPaused {
        _handleLend(
            _nfts,
            _tokenIds,
            _maxRentDurations,
            _dailyRentPrices,
            _nftPrices,
            _paymentTokens
        );
    }

    function _handleLend(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint8[] memory _maxRentDurations,
        bytes4[] memory _dailyRentPrices,
        bytes4[] memory _nftPrices,
        IResolver.PaymentToken[] memory _paymentTokens
    ) private {
        for (uint256 i = 0; i < _nfts.length; i++) {
            ensureIsLendable(
                _maxRentDurations[i],
                _dailyRentPrices[i],
                _nftPrices[i]
            );
            LendingRenting storage item = lendingRenting[
                keccak256(abi.encodePacked(_nfts[i], _tokenIds[i], lendingId))
            ];

            bool nftIs721 = is721(_nfts[i]);

            ensureIsNull(item.lending);
            ensureIsNull(item.renting);

            item.lending = Lending({
                lender: payable(msg.sender),
                maxRentDuration: _maxRentDurations[i],
                dailyRentPrice: _dailyRentPrices[i],
                nftPrice: _nftPrices[i],
                paymentToken: _paymentTokens[i]
            });
            emit Lent(
                _nfts[i],
                _tokenIds[i],
                1,
                lendingId,
                msg.sender,
                _maxRentDurations[i],
                _dailyRentPrices[i],
                _nftPrices[i],
                nftIs721,
                _paymentTokens[i]
            );
            lendingId++;
            if (is721(_nfts[i])) {
                IERC721(_nfts[i]).transferFrom(
                    msg.sender,
                    address(this),
                    _tokenIds[i]
                );
            } else {
                revert("ReNFT::unsupported token type");
            }
        }
    }

    // TODO: create function renting
    function rent(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds,
        uint8[] memory _rentDurations
    ) external override whenNotPaused {}

    function _handleRent(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds,
        uint8[] memory _rentDurations
    ) private {
        for (uint256 i = 0; i < _nfts.length; i++) {
            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(_nfts[i], _tokenIds[i], _lendingIds[i])
                )
            ];
            ensureIsNotNull(item.lending);
            ensureIsNull(item.renting);
            ensureIsRentable(item.lending, _rentDurations[i], msg.sender);

            uint8 paymentTokenIx = uint8(item.lending.paymentToken);
            ensureTokenNotSentinel(paymentTokenIx);
            address paymentToken = resolver.getPaymentToken(paymentTokenIx);
            uint256 decimals = ERC20(paymentToken).decimals();

            {
                uint256 scale = 10**decimals;
                uint256 rentPrice = _rentDurations[i] *
                    unpackPrice(item.lending.dailyRentPrice, scale);
                uint256 nftPrice = 1 *
                    unpackPrice(item.lending.nftPrice, scale);

                require(rentPrice > 0, "ReNFT::rent price is zero");
                require(nftPrice > 0, "ReNFT::nft price is zero");

                ERC20(paymentToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    rentPrice + nftPrice
                );
            }
        }
    }

    function returnIt(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) external override whenNotPaused {}

    function stopLending(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) external override whenNotPaused {}

    function claimCollateral(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) external override whenNotPaused {}
}
