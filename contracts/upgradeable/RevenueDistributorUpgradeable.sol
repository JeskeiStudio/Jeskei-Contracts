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

// =============================================================================
// UPGRADEABLE REVENUE DISTRIBUTOR
// =============================================================================

contract RevenueDistributorUpgradeable is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    
    struct RevenueShare {
        address recipient;
        uint256 percentage;
        bool isActive;
    }
    
    mapping(uint256 => RevenueShare[]) public assetShares;
    mapping(uint256 => uint256) public totalRevenue;
    mapping(uint256 => mapping(address => uint256)) public contributorEarnings;
    
    uint256 public platformFee;
    address public platformTreasury;
    AssetRegistryUpgradeable public assetRegistry;
    
    // New storage for future upgrades
    mapping(uint256 => uint256) public assetRevenueStreaks; // For gamification
    mapping(address => uint256) public creatorTotalEarnings; // For analytics
    uint256[50] private __gap;
    
    event RevenueDistributed(uint256 indexed assetId, address indexed recipient, uint256 amount);
    event RevenueSharesSet(uint256 indexed assetId, address[] recipients, uint256[] percentages);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _assetRegistry, address _platformTreasury) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        assetRegistry = AssetRegistryUpgradeable(_assetRegistry);
        platformTreasury = _platformTreasury;
        platformFee = 1500; // 15%
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setRevenueShares(
        uint256 assetId,
        address[] calldata recipients,
        uint256[] calldata percentages
    ) external {
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        require(recipients.length == percentages.length, "Array length mismatch");
        
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
        
        uint256 platformFeeAmount = (amount * platformFee) / 10000;
        uint256 availableRevenue = amount - platformFeeAmount;
        
        payable(platformTreasury).transfer(platformFeeAmount);
        
        RevenueShare[] storage shares = assetShares[assetId];
        
        if (shares.length == 0) {
            address owner = assetRegistry.ownerOf(assetId);
            payable(owner).transfer(availableRevenue);
            contributorEarnings[assetId][owner] += availableRevenue;
            creatorTotalEarnings[owner] += availableRevenue;
            emit RevenueDistributed(assetId, owner, availableRevenue);
        } else {
            for (uint i = 0; i < shares.length; i++) {
                if (shares[i].isActive) {
                    uint256 payment = (availableRevenue * shares[i].percentage) / 10000;
                    if (payment > 0) {
                        payable(shares[i].recipient).transfer(payment);
                        contributorEarnings[assetId][shares[i].recipient] += payment;
                        creatorTotalEarnings[shares[i].recipient] += payment;
                        emit RevenueDistributed(assetId, shares[i].recipient, payment);
                    }
                }
            }
        }
        
        totalRevenue[assetId] += amount;
        assetRevenueStreaks[assetId]++;
    }

    function getAssetShares(uint256 assetId) external view returns (RevenueShare[] memory) {
        return assetShares[assetId];
    }

    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        require(_platformFee <= 2500, "Platform fee too high");
        platformFee = _platformFee;
    }

    function updateAssetRegistry(address _assetRegistry) external onlyOwner {
        require(_assetRegistry != address(0), "Invalid address");
        assetRegistry = AssetRegistryUpgradeable(_assetRegistry);
    }
}
