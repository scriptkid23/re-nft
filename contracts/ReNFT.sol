//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./interface/IReNFT.sol";
import "./interface/IResolver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./base/Schemas.sol";

contract ReNFT is IReNft, ERC721Holder, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    IResolver private resolver;
    address payable private beneficiary;
    uint256 public rentFee;
    uint256 private lendingId = 1;
    uint256 private constant SECONDS_IN_DAY = 86400;

    mapping(bytes32 => LendingRenting) private lendingRenting;

    constructor(
        address payable _beneficiary,
        uint256 _rentFee,
        address _resolver
    ) {
        resolver = IResolver(_resolver);
        beneficiary = _beneficiary;
        rentFee = _rentFee;
    }

    // TODO: create function lending
    function lend(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint8[] memory _maxRentDurations,
        bytes4[] memory _dailyRentPrices,
        bytes4[] memory _nftPrices,
        IResolver.PaymentToken[] memory _paymentTokens
    ) external override nonReentrant whenNotPaused {
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
    ) external override nonReentrant whenNotPaused {
        _handleRent(_nfts, _tokenIds, _lendingIds, _rentDurations);
    }

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

    // function with role borrower
    function returnIt(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) external override nonReentrant whenNotPaused {
        _handleReturn(_nfts, _tokenIds, _lendingIds);
    }

    function _handleReturn(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) private {
        for (uint256 i = 0; i < _nfts.length; i++) {
            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(_nfts[i], _tokenIds[i], _lendingIds[i])
                )
            ];
            ensureIsNotNull(item.lending);
            ensureIsReturnable(item.renting, msg.sender, block.timestamp);
            uint256 secondsSinceRentStart = block.timestamp -
                item.renting.rentedAt;
            _distributePayments(item, secondsSinceRentStart);
            emit Returned(_lendingIds[i], uint32(block.timestamp));
            delete item.renting;
        }
    }

    function stopLending(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) external override nonReentrant whenNotPaused {
        _handleStopLending(_nfts, _tokenIds, _lendingIds);
    }

    function _handleStopLending(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) private {
        for (uint256 i = 0; i < _nfts.length; i++) {
            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(_nfts[i], _tokenIds[i], _lendingIds[i])
                )
            ];
            ensureIsNotNull(item.lending);
            ensureIsNull(item.renting);
            ensureIsStoppable(item.lending, msg.sender);

            emit LendingStopped(_lendingIds[i], uint32(block.timestamp));
            delete item.lending;
            _safeTransfer(_nfts[i], _tokenIds[i], address(this), msg.sender);
        }
    }

    function claimCollateral(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) external override nonReentrant whenNotPaused {
        _handleClaimCollateral(_nfts, _tokenIds, _lendingIds);
    }

    function _handleClaimCollateral(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) private {
        for (uint256 i = 0; i < _nfts.length; i++) {
            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(_nfts[i], _tokenIds[i], _lendingIds[i])
                )
            ];
            ensureIsNotNull(item.lending);
            ensureIsNotNull(item.renting);
            ensureIsClaimable(item.renting, block.timestamp);
            _distributeClaimPayment(item);
            emit CollateralClaimed(_lendingIds[i], uint32(block.timestamp));

            delete item.lending;
            delete item.renting;
        }
    }

    function setRentFee(uint256 _rentFee) external nonReentrant onlyOwner {
        require(_rentFee < 10000, "fee exceeds 100");
        rentFee = _rentFee;
    }

    function setBeneficiary(address payable _newBeneficiary)
        external
        nonReentrant
        onlyOwner
    {
        beneficiary = _newBeneficiary;
    }

    function setPaused() public nonReentrant onlyOwner {
        _pause();
    }

    function setUnPaused() public nonReentrant onlyOwner {
        _unpause();
    }

    function ensureIsNotZeroAddr(address _addr) private pure {
        require(_addr != address(0), "ReNFT::zero address");
    }

    // Util function

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

    function ensureIsReturnable(
        Renting memory _renting,
        address _msgSender,
        uint256 _blockTimestamp
    ) private pure {
        require(_renting.renter == _msgSender, "ReNFT::not renter");
        require(
            !isPastReturnDate(_renting, _blockTimestamp),
            "ReNFT::past return date"
        );
    }

    function ensureIsStoppable(Lending memory _lending, address _msgSender)
        private
        pure
    {
        require(_lending.lender == _msgSender, "ReNFT::not lender");
    }

    function isPastReturnDate(Renting memory _renting, uint256 _now)
        private
        pure
        returns (bool)
    {
        require(_now > _renting.rentedAt, "ReNFT::now before rented");
        return
            _now - _renting.rentedAt > _renting.rentDuration * SECONDS_IN_DAY;
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

    function ensureIsClaimable(Renting memory _renting, uint256 _blockTimestamp)
        private
        pure
    {
        require(
            isPastReturnDate(_renting, _blockTimestamp),
            "ReNFT::return date not passed"
        );
    }

    function takeFee(uint256 _rent, IResolver.PaymentToken _paymentToken)
        private
        returns (uint256 fee)
    {
        fee = _rent * rentFee;
        fee /= 10000;
        uint8 paymentTokenIx = uint8(_paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        ERC20 paymentToken = ERC20(resolver.getPaymentToken(paymentTokenIx));
        paymentToken.safeTransfer(beneficiary, fee);
    }

    function _distributePayments(
        LendingRenting storage _lendingRenting,
        uint256 _secondsSinceRentStart
    ) private {
        uint8 paymentTokenIx = uint8(_lendingRenting.lending.paymentToken);
        // ensureTokenNotSentinel(paymentTokenIx);
        address paymentToken = resolver.getPaymentToken(paymentTokenIx);
        uint256 decimals = ERC20(paymentToken).decimals();

        uint256 scale = 10**decimals;
        uint256 nftPrice = 1 *
            unpackPrice(_lendingRenting.lending.nftPrice, scale);
        uint256 rentPrice = unpackPrice(
            _lendingRenting.lending.dailyRentPrice,
            scale
        );
        // số tiền cần trả khi đúng hạn
        uint256 totalRenterPmtWoCollateral = rentPrice *
            _lendingRenting.renting.rentDuration;
        // số tiền cần trả lại lender ~ số ngày đã sử dụng * rentPrice
        uint256 sendLenderAmt = (_secondsSinceRentStart * rentPrice) /
            SECONDS_IN_DAY;
        require(
            totalRenterPmtWoCollateral > 0,
            "Total payment wo collateral is zero"
        );
        require(sendLenderAmt > 0, "ReNFT::lender payment is zero");
        // số tiền cần trả lại renter
        uint256 sendRenterAmt = totalRenterPmtWoCollateral - sendLenderAmt;
        // số tiền phí được share với beneficiary
        uint256 takenFee = takeFee(
            sendLenderAmt,
            _lendingRenting.lending.paymentToken
        );

        sendLenderAmt -= takenFee; // số tiền thực tế mà lender nhận được
        sendRenterAmt += nftPrice; // giá tài sản thế chấp được trả lại renter

        ERC20(paymentToken).safeTransfer(
            _lendingRenting.lending.lender,
            sendLenderAmt
        );
        ERC20(paymentToken).safeTransfer(
            _lendingRenting.renting.renter,
            sendRenterAmt
        );
    }

    function _distributeClaimPayment(LendingRenting memory _lendingRenting)
        private
    {
        uint8 paymentTokenIx = uint8(_lendingRenting.lending.paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        ERC20 paymentToken = ERC20(resolver.getPaymentToken(paymentTokenIx));

        uint256 decimals = ERC20(paymentToken).decimals();
        uint256 scale = 10**decimals;
        uint256 nftPrice = 1 *
            unpackPrice(_lendingRenting.lending.nftPrice, scale);
        uint256 rentPrice = unpackPrice(
            _lendingRenting.lending.dailyRentPrice,
            scale
        );
        // số tiền thuê tối đa của renter
        uint256 maxRentPayment = rentPrice *
            _lendingRenting.renting.rentDuration;
        uint256 takenFee = takeFee(
            maxRentPayment,
            IResolver.PaymentToken(paymentTokenIx)
        );
        // do renter trả muộn hoặc không trả sẽ lấy số tiền thế chấp nft của renter để ra giá trị cuối 
        uint256 finalAmt = maxRentPayment + nftPrice;

        require(maxRentPayment > 0, "ReNFT::collateral plus rent is zero");

        // beneficiary sẽ nhận được khoản phí từ lender
        paymentToken.safeTransfer(
            _lendingRenting.lending.lender,
            finalAmt - takenFee
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
        // giá trị tối đa của số thực 9999.9999
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

    function _safeTransfer(
        address _nft,
        uint256 _tokenId,
        address _from,
        address _to
    ) private {
        if (is721(_nft)) {
            IERC721(_nft).safeTransferFrom(_from, _to, _tokenId);
        } else {
            revert("Unsupported token type");
        }
    }

    function is721(address _nft) private view returns (bool) {
        return IERC165(_nft).supportsInterface(type(IERC721).interfaceId);
    }
}
