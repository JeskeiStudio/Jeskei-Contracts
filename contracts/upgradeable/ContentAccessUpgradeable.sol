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
import "./AssetRegistryUpgradeable.sol";
import "./RevenueDistributorUpgradeable.sol";

// =============================================================================
// UPGRADEABLE CONTENT ACCESS
// =============================================================================

contract ContentAccessUpgradeable is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    
    struct AccessGrant {
        uint256 expiryTime;
        bool isActive;
        uint256 grantTime;
    }
    
    mapping(address => mapping(uint256 => AccessGrant)) public userAccess;
    mapping(uint256 => uint256) public assetPrices;
    mapping(uint256 => bool) public isPublicAsset;
    
    AssetRegistryUpgradeable public assetRegistry;
    RevenueDistributorUpgradeable public revenueDistributor;
    
    // New storage for future upgrades
    mapping(uint256 => uint256) public assetViewCount; // For analytics
    mapping(address => uint256[]) public userPurchaseHistory; // For recommendations
    mapping(uint256 => mapping(address => bool)) public assetSubscribers; // For subscription model
    uint256[50] private __gap;
    
    event AccessGranted(address indexed user, uint256 indexed assetId, uint256 expiryTime);
    event AccessPurchased(address indexed user, uint256 indexed assetId, uint256 price);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _assetRegistry, address _revenueDistributor) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        assetRegistry = AssetRegistryUpgradeable(_assetRegistry);
        revenueDistributor = RevenueDistributorUpgradeable(_revenueDistributor);
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setAssetPrice(uint256 assetId, uint256 price) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        assetPrices[assetId] = price;
    }

    function purchaseAccess(uint256 assetId, uint256 duration) external payable nonReentrant {
        require(!isPublicAsset[assetId], "Asset is public");
        require(assetPrices[assetId] > 0, "Asset not for sale");
        require(msg.value >= assetPrices[assetId], "Insufficient payment");
        
        userAccess[msg.sender][assetId] = AccessGrant({
            expiryTime: block.timestamp + duration,
            isActive: true,
            grantTime: block.timestamp
        });
        
        // Track analytics
        assetViewCount[assetId]++;
        userPurchaseHistory[msg.sender].push(assetId);
        
        revenueDistributor.distributeRevenue{value: msg.value}(assetId, msg.value);
        
        emit AccessPurchased(msg.sender, assetId, msg.value);
        emit AccessGranted(msg.sender, assetId, block.timestamp + duration);
    }

    function hasAccess(address user, uint256 assetId) external view returns (bool) {
        if (isPublicAsset[assetId]) return true;
        if (assetRegistry.ownerOf(assetId) == user) return true;
        
        AccessGrant memory grant = userAccess[user][assetId];
        return grant.isActive && block.timestamp <= grant.expiryTime;
    }

    // Future upgrade functions
    function subscribeToAsset(uint256 assetId) external {
        assetSubscribers[assetId][msg.sender] = true;
    }

    function getAssetViewCount(uint256 assetId) external view returns (uint256) {
        return assetViewCount[assetId];
    }

    function getUserPurchaseHistory(address user) external view returns (uint256[] memory) {
        return userPurchaseHistory[user];
    }
}
