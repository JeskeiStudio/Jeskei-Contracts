// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

// =============================================================================
// UPGRADEABLE ASSET REGISTRY
// =============================================================================

contract AssetRegistryUpgradeable is 
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    
    struct MediaAsset {
        address creator;
        string contentHash;
        string metadataURI;
        uint256 revenueShare;
        bool isVerified;
        uint256 creationTime;
        string storageProvider;
        uint256 hostingFeesPaid;
        string assetType;
        bool isPublic;
        uint256 price;
    }

    struct Contributor {
        address contributorAddress;
        uint256 sharePercentage;
        string role;
    }

    mapping(uint256 => MediaAsset) public assets;
    mapping(uint256 => Contributor[]) public assetContributors;
    mapping(uint256 => mapping(address => bool)) public contributorExists;
    mapping(address => uint256[]) public creatorAssets;
    mapping(address => uint256) public hostingBalance;
    
    uint256 public platformHostingFee;
    address public hostingTreasury;
    uint256 private _tokenIdCounter;
    
    // New storage variables for future upgrades
    mapping(uint256 => bytes32) public assetDataHash; // For additional asset data
    mapping(address => bool) public verifiedCreators; // For creator verification
    uint256[50] private __gap; // Reserve storage slots for future upgrades
    
    event AssetCreated(uint256 indexed tokenId, address indexed creator, string contentHash, string assetType, uint256 price);
    event ContributorAdded(uint256 indexed tokenId, address indexed contributor, uint256 sharePercentage, string role);
    event HostingFeePaid(address indexed creator, uint256 amount, uint256 platformFee);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _hostingTreasury) public initializer {
        __ERC721_init("Jeskei Media Assets", "JMA");
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        hostingTreasury = _hostingTreasury;
        platformHostingFee = 15; // 15% platform fee
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function createAsset(
        string memory contentHash,
        string memory metadataURI,
        string memory assetType,
        string memory storageProvider,
        bool isPublic,
        uint256 price
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(bytes(contentHash).length > 0, "Content hash required");
        require(msg.value > 0, "Hosting fee required");
        
        uint256 platformFee = (msg.value * platformHostingFee) / 100;
        uint256 creatorFee = msg.value - platformFee;
        
        hostingBalance[msg.sender] += creatorFee;
        hostingBalance[hostingTreasury] += platformFee;
        
        uint256 tokenId = _tokenIdCounter++;
        
        assets[tokenId] = MediaAsset({
            creator: msg.sender,
            contentHash: contentHash,
            metadataURI: metadataURI,
            revenueShare: 10000,
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

    // View functions
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

    // Admin functions
    function setPlatformHostingFee(uint256 _fee) external onlyOwner {
        require(_fee <= 25, "Fee too high");
        platformHostingFee = _fee;
    }

    function setHostingTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        hostingTreasury = _treasury;
    }

    // Future upgrade functions
    function setAssetDataHash(uint256 tokenId, bytes32 dataHash) external {
        require(ownerOf(tokenId) == msg.sender, "Not asset owner");
        assetDataHash[tokenId] = dataHash;
    }

    function verifyCreator(address creator) external onlyOwner {
        verifiedCreators[creator] = true;
    }

    // Override required functions
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Upgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
