// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============================================================================
// ASSET REGISTRY - Core NFT contract for all media assets (OpenZeppelin v5)
// =============================================================================

contract AssetRegistry is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard, Pausable {
    
    struct MediaAsset {
        address creator;
        string contentHash; // IPFS hash or storage reference
        string metadataURI;
        uint256 revenueShare; // Creator's default share in basis points (10000 = 100%)
        bool isVerified;
        uint256 creationTime;
        string storageProvider; // "ipfs", "azure", "private"
        uint256 hostingFeesPaid;
        string assetType; // "video", "audio", "script", "performance", "edit"
        bool isPublic; // true for free content, false for paid
        uint256 price; // Price in wei (0 for free content)
    }

    struct Contributor {
        address contributorAddress;
        uint256 sharePercentage; // In basis points (100 = 1%)
        string role; // "actor", "writer", "composer", etc.
    }

    mapping(uint256 => MediaAsset) public assets;
    mapping(uint256 => Contributor[]) public assetContributors;
    mapping(uint256 => mapping(address => bool)) public contributorExists;
    mapping(address => uint256[]) public creatorAssets;
    
    // Hosting fee management
    mapping(address => uint256) public hostingBalance;
    uint256 public platformHostingFee = 15; // 15% platform fee on hosting
    address public hostingTreasury;
    
    uint256 private _tokenIdCounter;
    
    event AssetCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string contentHash,
        string assetType,
        uint256 price
    );
    
    event ContributorAdded(
        uint256 indexed tokenId,
        address indexed contributor,
        uint256 sharePercentage,
        string role
    );
    
    event HostingFeePaid(
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    constructor(address _hostingTreasury) ERC721("Jeskei Media Assets", "JMA") Ownable(msg.sender) {
        hostingTreasury = _hostingTreasury;
    }

    function createAsset(
        string memory contentHash,
        string memory metadataURI,
        string memory assetType,
        string memory storageProvider,
        bool isPublic,
        uint256 price
    ) external payable nonReentrant returns (uint256) {
        require(bytes(contentHash).length > 0, "Content hash required");
        require(msg.value > 0, "Hosting fee required");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformHostingFee) / 100;
        uint256 creatorFee = msg.value - platformFee;
        
        // Update hosting balances
        hostingBalance[msg.sender] += creatorFee;
        hostingBalance[hostingTreasury] += platformFee;
        
        uint256 tokenId = _tokenIdCounter++;
        
        assets[tokenId] = MediaAsset({
            creator: msg.sender,
            contentHash: contentHash,
            metadataURI: metadataURI,
            revenueShare: 10000, // 100% initially to creator
            isVerified: false,
            creationTime: block.timestamp,
            storageProvider: storageProvider,
            hostingFeesPaid: msg.value,
            assetType: assetType,
            isPublic: isPublic,
            price: price
        });
        
        creatorAssets[msg.sender].push(tokenId);
        
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURI);
        
        emit AssetCreated(tokenId, msg.sender, contentHash, assetType, price);
        emit HostingFeePaid(msg.sender, msg.value, platformFee);
        
        return tokenId;
    }

    function addContributor(
        uint256 tokenId,
        address contributor,
        uint256 sharePercentage,
        string memory role
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not asset owner");
        require(contributor != address(0), "Invalid contributor");
        require(sharePercentage > 0 && sharePercentage <= 10000, "Invalid share");
        require(!contributorExists[tokenId][contributor], "Contributor already exists");
        
        // Check total shares don't exceed 100%
        uint256 totalShares = 0;
        for (uint i = 0; i < assetContributors[tokenId].length; i++) {
            totalShares += assetContributors[tokenId][i].sharePercentage;
        }
        require(totalShares + sharePercentage <= 10000, "Exceeds 100% shares");
        
        assetContributors[tokenId].push(Contributor({
            contributorAddress: contributor,
            sharePercentage: sharePercentage,
            role: role
        }));
        
        contributorExists[tokenId][contributor] = true;
        
        emit ContributorAdded(tokenId, contributor, sharePercentage, role);
    }

    function getAssetContributors(uint256 tokenId) external view returns (Contributor[] memory) {
        return assetContributors[tokenId];
    }

    function getCreatorAssets(address creator) external view returns (uint256[] memory) {
        return creatorAssets[creator];
    }

    function withdrawHostingBalance() external nonReentrant {
        uint256 balance = hostingBalance[msg.sender];
        require(balance > 0, "No balance to withdraw");
        
        hostingBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }

    // Override required functions
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
