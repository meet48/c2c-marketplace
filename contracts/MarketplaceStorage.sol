// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Marketplace storage.
 */
contract MarketplaceStorage {

    address public recipient;
    
    uint256 public fee = 300;

    // Method of payment.
    uint256 internal constant PAYTYPE_NATIVE = 0;
    uint256 internal constant PAYTYPE_ERC20 = 1;

    // ERC20 contract.
    address[] public payTokens;

    uint256 public maxRoyaltiesFee = 5000;

    // User Cancels Signature.
    mapping(bytes => bool) internal _cancelSignatures;

    // Order struct hash.
    bytes32 internal constant ORDER_HASH = keccak256("Order(address signer,address nftContract,uint256 nftTokenId,uint256 payType,address payToken,uint256 price,uint256 startTime,uint256 endTime,Royalties royalties,uint256 salt)Royalties(address recipient,uint256 fee)");
    
    // Offer struct hash.
    bytes32 internal constant OFFER_HASH = keccak256("Offer(address signer,address nftContract,uint256 nftTokenId,address nftOwner,address payToken,uint256 price,uint256 startTime,uint256 endTime,Royalties royalties,uint256 salt)Royalties(address recipient,uint256 fee)");

    // Royalties struct hash.
    bytes32 internal constant ROYALTIES_HASH = keccak256("Royalties(address recipient,uint256 fee)");

    // Seller's sales signature data.
    struct Order {
        address signer;
        address nftContract;
        uint256 nftTokenId;
        uint256 payType;
        address payToken;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        Royalties royalties;
        uint256 salt;
        bytes signature;
    }

    // Buyer's offer signature data.
    struct Offer {
        address signer;
        address nftContract;
        uint256 nftTokenId;
        address nftOwner;
        address payToken;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        Royalties royalties;
        uint256 salt;
        bytes signature;
    }

    // Royalties data.
    struct Royalties {
        address recipient;
        uint256 fee;
    }

    event Cancel(bytes indexed signature);
    event Record(address indexed nftContract , uint256 indexed tokenId , address from , address to , address payToken , uint256 price);
}
