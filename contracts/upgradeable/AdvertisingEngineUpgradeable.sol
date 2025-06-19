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
// UPGRADEABLE ADVERTISING ENGINE
// =============================================================================

contract AdvertisingEngineUpgradeable is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    
    struct AdCampaign {
        address advertiser;
        string metadataURI;
        uint256 budget;
        uint256 spent;
        uint256 viewerPaymentRate;
        uint256 creatorPaymentRate;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string[] targetingTags;
    }
    
    mapping(uint256 => AdCampaign) public campaigns;
    mapping(address => uint256) public advertiserBalance;
    mapping(address => uint256) public viewerEarnings;
    mapping(address => uint256) public creatorAdEarnings;
    
    uint256 public campaignCounter;
    uint256 public platformAdFee;
    address public adTreasury;
    
    // New storage for future upgrades
    mapping(uint256 => uint256) public campaignViews; // For analytics
    mapping(address => uint256[]) public viewerCampaignHistory; // For targeting
    mapping(string => uint256) public tagPopularity; // For tag analytics
    uint256[50] private __gap;
    
    event CampaignCreated(uint256 indexed campaignId, address advertiser, uint256 budget);
    event AdViewed(uint256 indexed campaignId, address viewer, address creator, uint256 viewerPayment, uint256 creatorPayment);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _adTreasury) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        adTreasury = _adTreasury;
        platformAdFee = 1000; // 10%
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function createCampaign(
        string memory metadataURI,
        uint256 viewerPaymentRate,
        uint256 creatorPaymentRate,
        uint256 duration,
        string[] memory targetingTags
    ) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "Campaign needs funding");
        require(viewerPaymentRate > 0, "Viewer payment required");
        require(creatorPaymentRate > 0, "Creator payment required");
        require(duration > 0, "Invalid duration");
        
        uint256 campaignId = campaignCounter++;
        
        campaigns[campaignId] = AdCampaign({
            advertiser: msg.sender,
            metadataURI: metadataURI,
            budget: msg.value,
            spent: 0,
            viewerPaymentRate: viewerPaymentRate,
            creatorPaymentRate: creatorPaymentRate,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true,
            targetingTags: targetingTags
        });
        
        advertiserBalance[msg.sender] += msg.value;
        
        // Update tag popularity
        for (uint i = 0; i < targetingTags.length; i++) {
            tagPopularity[targetingTags[i]]++;
        }
        
        emit CampaignCreated(campaignId, msg.sender, msg.value);
        return campaignId;
    }

    function recordAdView(
        uint256 campaignId,
        address viewer,
        address creator
    ) external onlyOwner nonReentrant {
        require(campaigns[campaignId].isActive, "Campaign not active");
        require(block.timestamp <= campaigns[campaignId].endTime, "Campaign expired");
        require(viewer != address(0) && creator != address(0), "Invalid addresses");
        
        AdCampaign storage campaign = campaigns[campaignId];
        
        uint256 totalPayment = campaign.viewerPaymentRate + campaign.creatorPaymentRate;
        uint256 platformFee = (totalPayment * platformAdFee) / 10000;
        uint256 totalCost = totalPayment + platformFee;
        
        require(campaign.budget >= campaign.spent + totalCost, "Insufficient campaign budget");
        
        campaign.spent += totalCost;
        advertiserBalance[campaign.advertiser] -= totalCost;
        
        viewerEarnings[viewer] += campaign.viewerPaymentRate;
        creatorAdEarnings[creator] += campaign.creatorPaymentRate;
        
        // Update analytics
        campaignViews[campaignId]++;
        viewerCampaignHistory[viewer].push(campaignId);
        
        payable(viewer).transfer(campaign.viewerPaymentRate);
        payable(creator).transfer(campaign.creatorPaymentRate);
        payable(adTreasury).transfer(platformFee);
        
        emit AdViewed(campaignId, viewer, creator, campaign.viewerPaymentRate, campaign.creatorPaymentRate);
    }

    function getCampaignTargetingTags(uint256 campaignId) external view returns (string[] memory) {
        return campaigns[campaignId].targetingTags;
    }

    function getCampaignViews(uint256 campaignId) external view returns (uint256) {
        return campaignViews[campaignId];
    }

    function getViewerCampaignHistory(address viewer) external view returns (uint256[] memory) {
        return viewerCampaignHistory[viewer];
    }

    function getTagPopularity(string memory tag) external view returns (uint256) {
        return tagPopularity[tag];
    }

    function setPlatformAdFee(uint256 _platformAdFee) external onlyOwner {
        require(_platformAdFee <= 2000, "Fee too high");
        platformAdFee = _platformAdFee;
    }
}
