// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AssetRegistry.sol";

// =============================================================================
// REVENUE DISTRIBUTOR - Handles automated payment splitting (OpenZeppelin v5)
// =============================================================================

contract RevenueDistributor is Ownable, ReentrancyGuard, Pausable {
    
    struct RevenueShare {
        address recipient;
        uint256 percentage; // In basis points (100 = 1%)
        bool isActive;
    }
    
    mapping(uint256 => RevenueShare[]) public assetShares;
    mapping(uint256 => uint256) public totalRevenue;
    mapping(uint256 => mapping(address => uint256)) public contributorEarnings;
    
    uint256 public platformFee = 1500; // 15% platform fee
    address public platformTreasury;
    AssetRegistry public assetRegistry;
    
    event RevenueDistributed(uint256 indexed assetId, address indexed recipient, uint256 amount);
    event RevenueSharesSet(uint256 indexed assetId, address[] recipients, uint256[] percentages);
    
    constructor(address _assetRegistry, address _platformTreasury) Ownable(msg.sender) {
        assetRegistry = AssetRegistry(_assetRegistry);
        platformTreasury = _platformTreasury;
    }

    function setRevenueShares(
        uint256 assetId,
        address[] calldata recipients,
        uint256[] calldata percentages
    ) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        require(recipients.length == percentages.length, "Array length mismatch");
        
        // Clear existing shares
        delete assetShares[assetId];
        
        uint256 totalPercentage = 0;
        for (uint i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(percentages[i] > 0, "Invalid percentage");
            
            totalPercentage += percentages[i];
            
            assetShares[assetId].push(RevenueShare({
                recipient: recipients[i],
                percentage: percentages[i],
                isActive: true
            }));
        }
        
        require(totalPercentage <= 10000, "Total percentage exceeds 100%");
        
        emit RevenueSharesSet(assetId, recipients, percentages);
    }

    function distributeRevenue(uint256 assetId, uint256 amount) external payable nonReentrant whenNotPaused {
        require(msg.value == amount, "Incorrect payment amount");
        require(amount > 0, "Amount must be greater than 0");
        
        // Calculate platform fee
        uint256 platformFeeAmount = (amount * platformFee) / 10000;
        uint256 availableRevenue = amount - platformFeeAmount;
        
        // Send platform fee
        payable(platformTreasury).transfer(platformFeeAmount);
        
        // Distribute to contributors
        RevenueShare[] storage shares = assetShares[assetId];
        
        if (shares.length == 0) {
            // No shares set, send all to asset owner
            address owner = assetRegistry.ownerOf(assetId);
            payable(owner).transfer(availableRevenue);
            contributorEarnings[assetId][owner] += availableRevenue;
            emit RevenueDistributed(assetId, owner, availableRevenue);
        } else {
            // Distribute according to shares
            for (uint i = 0; i < shares.length; i++) {
                if (shares[i].isActive) {
                    uint256 payment = (availableRevenue * shares[i].percentage) / 10000;
                    if (payment > 0) {
                        payable(shares[i].recipient).transfer(payment);
                        contributorEarnings[assetId][shares[i].recipient] += payment;
                        emit RevenueDistributed(assetId, shares[i].recipient, payment);
                    }
                }
            }
        }
        
        totalRevenue[assetId] += amount;
    }

    function getAssetShares(uint256 assetId) external view returns (RevenueShare[] memory) {
        return assetShares[assetId];
    }

    function getContributorEarnings(uint256 assetId, address contributor) external view returns (uint256) {
        return contributorEarnings[assetId][contributor];
    }

    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        require(_platformFee <= 2500, "Platform fee too high"); // Max 25%
        platformFee = _platformFee;
    }
}