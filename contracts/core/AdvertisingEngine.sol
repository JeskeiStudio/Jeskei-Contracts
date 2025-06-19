// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============================================================================
// ADVERTISING ENGINE - Privacy-first advertising with revenue sharing
// =============================================================================

contract AdvertisingEngine is Ownable, ReentrancyGuard, Pausable {
    
    struct AdCampaign {
        address advertiser;
        string metadataURI; // Contains targeting criteria, creative assets
        uint256 budget;
        uint256 spent;
        uint256 viewerPaymentRate; // Wei per view
        uint256 creatorPaymentRate; // Wei per view
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string[] targetingTags;
    }
    
    struct AdView {
        uint256 campaignId;
        address viewer;
        address creator;
        uint256 timestamp;
        uint256 viewerPayment;
        uint256 creatorPayment;
    }
    
    mapping(uint256 => AdCampaign) public campaigns;
    mapping(address => uint256) public advertiserBalance;
    mapping(address => uint256) public viewerEarnings;
    mapping(address => uint256) public creatorAdEarnings;
    
    uint256 public campaignCounter;
    uint256 public platformAdFee = 1000; // 10% platform fee
    address public adTreasury;
    
    event CampaignCreated(uint256 indexed campaignId, address advertiser, uint256 budget);
    event AdViewed(uint256 indexed campaignId, address viewer, address creator, uint256 viewerPayment, uint256 creatorPayment);
    event CampaignFunded(uint256 indexed campaignId, uint256 amount);
    
    constructor(address _adTreasury) Ownable(msg.sender) {
        adTreasury = _adTreasury;
    }

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
        
        emit CampaignCreated(campaignId, msg.sender, msg.value);
        return campaignId;
    }

    function fundCampaign(uint256 campaignId) external payable {
        require(campaigns[campaignId].advertiser == msg.sender, "Not campaign owner");
        require(campaigns[campaignId].isActive, "Campaign not active");
        require(msg.value > 0, "Funding amount required");
        
        campaigns[campaignId].budget += msg.value;
        advertiserBalance[msg.sender] += msg.value;
        
        emit CampaignFunded(campaignId, msg.value);
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
        
        // Update campaign
        campaign.spent += totalCost;
        advertiserBalance[campaign.advertiser] -= totalCost;
        
        // Distribute payments
        viewerEarnings[viewer] += campaign.viewerPaymentRate;
        creatorAdEarnings[creator] += campaign.creatorPaymentRate;
        
        // Pay immediately
        payable(viewer).transfer(campaign.viewerPaymentRate);
        payable(creator).transfer(campaign.creatorPaymentRate);
        payable(adTreasury).transfer(platformFee);
        
        emit AdViewed(campaignId, viewer, creator, campaign.viewerPaymentRate, campaign.creatorPaymentRate);
    }

    function pauseCampaign(uint256 campaignId) external {
        require(campaigns[campaignId].advertiser == msg.sender, "Not campaign owner");
        campaigns[campaignId].isActive = false;
    }

    function resumeCampaign(uint256 campaignId) external {
        require(campaigns[campaignId].advertiser == msg.sender, "Not campaign owner");
        require(block.timestamp <= campaigns[campaignId].endTime, "Campaign expired");
        campaigns[campaignId].isActive = true;
    }

    function withdrawCampaignBalance(uint256 campaignId) external nonReentrant {
        require(campaigns[campaignId].advertiser == msg.sender, "Not campaign owner");
        require(!campaigns[campaignId].isActive || block.timestamp > campaigns[campaignId].endTime, "Campaign still active");
        
        uint256 remainingBudget = campaigns[campaignId].budget - campaigns[campaignId].spent;
        require(remainingBudget > 0, "No balance to withdraw");
        
        campaigns[campaignId].budget = campaigns[campaignId].spent;
        advertiserBalance[msg.sender] -= remainingBudget;
        
        payable(msg.sender).transfer(remainingBudget);
    }

    function getCampaignTargetingTags(uint256 campaignId) external view returns (string[] memory) {
        return campaigns[campaignId].targetingTags;
    }

    function setPlatformAdFee(uint256 _platformAdFee) external onlyOwner {
        require(_platformAdFee <= 2000, "Fee too high"); // Max 20%
        platformAdFee = _platformAdFee;
    }
}
