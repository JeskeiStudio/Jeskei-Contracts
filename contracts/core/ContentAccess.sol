// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AssetRegistry.sol";
import "./RevenueDistributor.sol";

// =============================================================================
// CONTENT ACCESS - Access control and licensing system (OpenZeppelin v5)
// =============================================================================

contract ContentAccess is Ownable, ReentrancyGuard {
    
    struct AccessGrant {
        uint256 expiryTime;
        bool isActive;
        uint256 grantTime;
    }
    
    mapping(address => mapping(uint256 => AccessGrant)) public userAccess;
    mapping(uint256 => uint256) public assetPrices; // In wei
    mapping(uint256 => bool) public isPublicAsset;
    
    AssetRegistry public assetRegistry;
    RevenueDistributor public revenueDistributor;
    
    event AccessGranted(address indexed user, uint256 indexed assetId, uint256 expiryTime);
    event AccessPurchased(address indexed user, uint256 indexed assetId, uint256 price);
    
    constructor(address _assetRegistry, address _revenueDistributor) Ownable(msg.sender) {
        assetRegistry = AssetRegistry(_assetRegistry);
        revenueDistributor = RevenueDistributor(_revenueDistributor);
    }

    function setAssetPrice(uint256 assetId, uint256 price) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        assetPrices[assetId] = price;
    }

    function setPublicAsset(uint256 assetId, bool isPublic) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        isPublicAsset[assetId] = isPublic;
    }

    function purchaseAccess(uint256 assetId, uint256 duration) external payable nonReentrant {
        require(!isPublicAsset[assetId], "Asset is public");
        require(assetPrices[assetId] > 0, "Asset not for sale");
        require(msg.value >= assetPrices[assetId], "Insufficient payment");
        
        // Grant access
        userAccess[msg.sender][assetId] = AccessGrant({
            expiryTime: block.timestamp + duration,
            isActive: true,
            grantTime: block.timestamp
        });
        
        // Distribute revenue
        revenueDistributor.distributeRevenue{value: msg.value}(assetId, msg.value);
        
        emit AccessPurchased(msg.sender, assetId, msg.value);
        emit AccessGranted(msg.sender, assetId, block.timestamp + duration);
    }

    function grantAccess(address user, uint256 assetId, uint256 duration) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        
        userAccess[user][assetId] = AccessGrant({
            expiryTime: block.timestamp + duration,
            isActive: true,
            grantTime: block.timestamp
        });
        
        emit AccessGranted(user, assetId, block.timestamp + duration);
    }

    function hasAccess(address user, uint256 assetId) external view returns (bool) {
        // Public assets are always accessible
        if (isPublicAsset[assetId]) {
            return true;
        }
        
        // Owner always has access
        if (assetRegistry.ownerOf(assetId) == user) {
            return true;
        }
        
        // Check if user has valid access grant
        AccessGrant memory grant = userAccess[user][assetId];
        return grant.isActive && block.timestamp <= grant.expiryTime;
    }

    function revokeAccess(address user, uint256 assetId) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        userAccess[user][assetId].isActive = false;
    }
}
