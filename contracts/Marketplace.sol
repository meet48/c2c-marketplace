// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MarketplaceStorage.sol";

/**
 * @dev Marketplace.
 */
contract Marketplace is Ownable , EIP712 , MarketplaceStorage {
    
    constructor() EIP712("marketplace" , "1") {
        recipient = msg.sender;
    }

    /**
     * @dev Setting the recipient Address.
     */
    function setRecipient(address _new) external onlyOwner {
        require(_new != address(0) , "zero address");
        require(recipient.code.length == 0 , "contract address");
        recipient = _new;
    }

    /**
     * @dev 100% equal 10000.
     */
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee < 10000 , "value error");
        fee = _fee;
    }

    /**
     * @dev Add payToken.
     */
    function addPayToken(address _token) external onlyOwner {
        require(_token != address(0) , "zero address");
        (bool _bool , ) = isExistPayToken(_token);
        require(!_bool , "existed");
        payTokens.push(_token);
    }

    /**
     * @dev Remove payToken.
     */
    function removePayToken(address _token) external onlyOwner {
        require(_token != address(0) , "zero address");
        (bool _bool , uint256 _index) = isExistPayToken(_token);
        require(_bool , "not existed");
        payTokens[_index] = payTokens[payTokens.length - 1];
        payTokens.pop();
    }

    /**
     * @dev Return whether payToken exists.
     */
    function isExistPayToken(address _token) public view returns (bool _bool , uint256 _index) {
        require(_token != address(0) , "zero address");
        uint256 length = payTokens.length;
        for(uint256 i ; i < length; i++){
            if(payTokens[i] == _token){
                _bool = true;
                _index = i;
                break;
            }
        }
    }

    function setMaxRoyaltiesFee(uint256 fee) external onlyOwner {
        require(fee < 10000 , "fee >= 10000");
        maxRoyaltiesFee = fee;
    }

    /**
     * @dev Cancel voucher.
     */
    function cancel(Order calldata orderVoucher) external {
        require(isOrder(orderVoucher) , "signature missmatch");
        require(orderVoucher.signer == msg.sender , "caller not signer");   
        _cancelSignatures[orderVoucher.signature] = true;
        emit Cancel(orderVoucher.signature);
    }

    function verifyOrder(Order calldata voucher) public view returns (bool) {
        require(isOrder(voucher) , "signature missmatch");
        require(!_cancelSignatures[voucher.signature] , "cancel");
        require(msg.sender == tx.origin , "caller is contract");
        require(msg.sender != voucher.signer , "caller is signer");
        require(isERC721(voucher.nftContract) || isERC1155(voucher.nftContract) , "nftContract error");
        require(voucher.payType == PAYTYPE_NATIVE || voucher.payType == PAYTYPE_ERC20 , "payType value error");
        require(voucher.price > 0 , "zero price");
        require(voucher.startTime <= block.timestamp , "no start");       
        require(block.timestamp <= voucher.endTime , "end");

        return true;
    }

    /**
     * @dev The buyer trades using the seller's voucher.
     */
    function buy(Order calldata voucher) external payable {
        require(verifyOrder(voucher) , "verify order fail");
        if(voucher.payType == PAYTYPE_NATIVE) {
            require(msg.value == voucher.price , "msg.value not equal price");
        }

        // Transfer nft.
        if(isERC721(voucher.nftContract)){
            IERC721(voucher.nftContract).transferFrom(voucher.signer , msg.sender , voucher.nftTokenId);
        }else if(isERC1155(voucher.nftContract)){
            IERC1155(voucher.nftContract).safeTransferFrom(voucher.signer , msg.sender , voucher.nftTokenId , 1 , '');
        }

        // Pay.
        if(voucher.payType == PAYTYPE_NATIVE) {
            _payNative(voucher.signer , voucher.royalties);

        }else{
            _payToken(voucher.payToken , voucher.price , msg.sender , voucher.signer , voucher.royalties);

        }

        emit Record(voucher.nftContract, voucher.nftTokenId, voucher.signer, msg.sender, voucher.payToken, voucher.price);
    }


    function isOrder(Order calldata voucher) public view returns (bool) {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
                    ORDER_HASH,
                    voucher.signer,
                    voucher.nftContract,
                    voucher.nftTokenId,
                    voucher.payType,
                    voucher.payToken,
                    voucher.price,
                    voucher.startTime,
                    voucher.endTime,
                    royaltiesHash(voucher.royalties),
                    voucher.salt
                )));

        return ECDSA.recover(_hash, voucher.signature) == voucher.signer;
    }

    /**
     * @dev Cancel voucher.
     */
    function cancel(Offer calldata offerVoucher) external {
        require(isOffer(offerVoucher) , "signature missmatch");
        require(offerVoucher.signer == msg.sender , "caller not signer");   
        _cancelSignatures[offerVoucher.signature] = true;
        emit Cancel(offerVoucher.signature);
    }

    function verifyOffer(Offer calldata voucher) public view returns (bool) {
        require(isOffer(voucher) , "signature missmatch");
        require(!_cancelSignatures[voucher.signature] , "cancel");
        require(msg.sender == tx.origin , "caller is contract");
        require(msg.sender != voucher.signer , "caller is signer");
        require(msg.sender == voucher.nftOwner , "caller is not nft owner");
        require(isERC721(voucher.nftContract) || isERC1155(voucher.nftContract) , "nftContract error");
        require(voucher.payToken != address(0) , "payToken zero address");
        require(voucher.price > 0 , "zero price");
        require(voucher.startTime <= block.timestamp , "no start");       
        require(block.timestamp <= voucher.endTime , "end");

        return true;
    }

    /**
     * @dev The owner of the nft receives the offer.
     */
    function receiveOffer(Offer calldata voucher) external {
        require(verifyOffer(voucher) , "verify order fail");

        // Transfer nft.
        if(isERC721(voucher.nftContract)){
            IERC721(voucher.nftContract).transferFrom(msg.sender , voucher.signer , voucher.nftTokenId);
        }else if(isERC1155(voucher.nftContract)){
            IERC1155(voucher.nftContract).safeTransferFrom(msg.sender , voucher.signer , voucher.nftTokenId , 1 , '');
        }

        // Pay.
        _payToken(voucher.payToken, voucher.price, voucher.signer, msg.sender, voucher.royalties);

        emit Record(voucher.nftContract, voucher.nftTokenId, msg.sender, voucher.signer, voucher.payToken, voucher.price);
    }

    function isOffer(Offer calldata voucher) public view returns (bool) {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
                    OFFER_HASH,
                    voucher.signer,
                    voucher.nftContract,
                    voucher.nftTokenId,
                    voucher.nftOwner,
                    voucher.payToken,
                    voucher.price,
                    voucher.startTime,
                    voucher.endTime,
                    royaltiesHash(voucher.royalties),
                    voucher.salt
                )));

        return ECDSA.recover(_hash, voucher.signature) == voucher.signer;
    }

    function royaltiesHash(Royalties memory royalties) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ROYALTIES_HASH,
            royalties.recipient,
            royalties.fee
        ));
    }

    /**
     * @dev Use ETH for payment.
     */
    function _payNative(address to , Royalties memory royalties) internal {
        uint256 platformAmount = msg.value * fee / 10000;
        uint256 royaltiesAmount;

        if(royalties.recipient != address(0)) {
            require(royalties.fee <= maxRoyaltiesFee , "fee > maxRoyaltiesFee");
            royaltiesAmount = msg.value * royalties.fee / 10000;
        }

        require(msg.value > platformAmount + royaltiesAmount , "fee error");

        payable(recipient).transfer(platformAmount);
        
        if(royaltiesAmount > 0){
            payable(royalties.recipient).transfer(royaltiesAmount);
        }
        
        payable(to).transfer(msg.value - platformAmount - royaltiesAmount);
    }

    /**
     * @dev Use ERC20 for payment.
     */
    function _payToken(address payToken , uint256 price , address from , address to , Royalties memory royalties) internal {
        (bool _bool , ) = isExistPayToken(payToken);
        require(_bool , "payToken not existed");

        IERC20 Token = IERC20(payToken);
        require(Token.allowance(from , address(this)) > price , "allowance < price");

        uint256 platformAmount = price * fee / 10000;
        uint256 royaltiesAmount;

        if(royalties.recipient != address(0)) {
            require(royalties.fee <= maxRoyaltiesFee , "fee > maxRoyaltiesFee");
            royaltiesAmount = price * royalties.fee / 10000;
        }

        require(price > platformAmount + royaltiesAmount , "fee error");

        Token.transferFrom(from , recipient , platformAmount);

        if(royaltiesAmount > 0){
            Token.transferFrom(from , royalties.recipient , royaltiesAmount);
        }
        
        Token.transferFrom(from , to , price - platformAmount - royaltiesAmount);
    }

    /**
     * @dev Returns whether the signature has been canceled.
     */
    function isCancel(bytes memory signature) public view returns (bool){
        return _cancelSignatures[signature];
    }

    /**
     * @dev Returns whether it is the ERC721 contract.
     */
    function isERC721(address _addr) public view returns (bool) {
        return IERC721(_addr).supportsInterface(0x80ac58cd);
    }

    /**
     * @dev Returns whether it is the ERC1155 contract.
     */
    function isERC1155(address _addr) public view returns (bool) {
        return IERC1155(_addr).supportsInterface(0xd9b67a26);
    }

}
