// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============================================================================
// CROWDFUNDING - Community funding for content projects
// =============================================================================

contract CrowdfundingPlatform is Ownable, ReentrancyGuard, Pausable {
    
    struct Campaign {
        address creator;
        string title;
        string description;
        string metadataURI;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isSuccessful;
        bool fundsWithdrawn;
        uint256[] rewardTiers;
        string[] rewardDescriptions;
    }
    
    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 timestamp;
        uint256 rewardTier;
        bool refunded;
    }
    
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Contribution[]) public campaignContributions;
    mapping(uint256 => mapping(address => uint256)) public contributorTotal;
    mapping(address => uint256[]) public creatorCampaigns;
    mapping(address => uint256[]) public contributorCampaigns;
    
    uint256 public campaignCounter;
    uint256 public platformFee = 500; // 5% platform fee
    address public crowdfundingTreasury;
    
    event CampaignCreated(uint256 indexed campaignId, address creator, uint256 targetAmount);
    event ContributionMade(uint256 indexed campaignId, address contributor, uint256 amount, uint256 rewardTier);
    event CampaignFunded(uint256 indexed campaignId, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed campaignId, address creator, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address contributor, uint256 amount);
    
    constructor(address _crowdfundingTreasury) Ownable(msg.sender) {
        crowdfundingTreasury = _crowdfundingTreasury;
    }

    function createCampaign(
        string memory title,
        string memory description,
        string memory metadataURI,
        uint256 targetAmount,
        uint256 duration,
        uint256[] memory rewardTiers,
        string[] memory rewardDescriptions
    ) external whenNotPaused returns (uint256) {
        require(targetAmount > 0, "Target amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(rewardTiers.length == rewardDescriptions.length, "Reward arrays length mismatch");
        require(bytes(title).length > 0, "Title required");
        require(bytes(description).length > 0, "Description required");
        
        uint256 campaignId = campaignCounter++;
        
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: title,
            description: description,
            metadataURI: metadataURI,
            targetAmount: targetAmount,
            raisedAmount: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true,
            isSuccessful: false,
            fundsWithdrawn: false,
            rewardTiers: rewardTiers,
            rewardDescriptions: rewardDescriptions
        });
        
        creatorCampaigns[msg.sender].push(campaignId);
        
        emit CampaignCreated(campaignId, msg.sender, targetAmount);
        return campaignId;
    }

    function contribute(uint256 campaignId, uint256 rewardTier) external payable nonReentrant whenNotPaused {
        Campaign storage campaign = campaigns[campaignId];
        
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp <= campaign.endTime, "Campaign ended");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(rewardTier < campaign.rewardTiers.length, "Invalid reward tier");
        require(msg.value >= campaign.rewardTiers[rewardTier], "Insufficient amount for reward tier");
        
        // Record contribution
        campaignContributions[campaignId].push(Contribution({
            contributor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            rewardTier: rewardTier,
            refunded: false
        }));
        
        // Update totals
        campaign.raisedAmount += msg.value;
        contributorTotal[campaignId][msg.sender] += msg.value;
        
        // Add to contributor's campaign list if first contribution
        if (contributorTotal[campaignId][msg.sender] == msg.value) {
            contributorCampaigns[msg.sender].push(campaignId);
        }
        
        // Check if campaign is now successful
        if (campaign.raisedAmount >= campaign.targetAmount && !campaign.isSuccessful) {
            campaign.isSuccessful = true;
            emit CampaignFunded(campaignId, campaign.raisedAmount);
        }
        
        emit ContributionMade(campaignId, msg.sender, msg.value, rewardTier);
    }

    function withdrawFunds(uint256 campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[campaignId];
        
        require(campaign.creator == msg.sender, "Not campaign creator");
        require(campaign.isSuccessful, "Campaign not successful");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");
        require(block.timestamp > campaign.endTime, "Campaign still active");
        
        campaign.fundsWithdrawn = true;
        
        uint256 platformFeeAmount = (campaign.raisedAmount * platformFee) / 10000;
        uint256 creatorAmount = campaign.raisedAmount - platformFeeAmount;
        
        // Transfer funds
        payable(crowdfundingTreasury).transfer(platformFeeAmount);
        payable(msg.sender).transfer(creatorAmount);
        
        emit FundsWithdrawn(campaignId, msg.sender, creatorAmount);
    }

    function requestRefund(uint256 campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[campaignId];
        
        require(block.timestamp > campaign.endTime, "Campaign still active");
        require(!campaign.isSuccessful, "Campaign was successful");
        require(contributorTotal[campaignId][msg.sender] > 0, "No contribution found");
        
        uint256 refundAmount = contributorTotal[campaignId][msg.sender];
        contributorTotal[campaignId][msg.sender] = 0;
        
        // Mark contributions as refunded
        Contribution[] storage contributions = campaignContributions[campaignId];
        for (uint i = 0; i < contributions.length; i++) {
            if (contributions[i].contributor == msg.sender) {
                contributions[i].refunded = true;
            }
        }
        
        payable(msg.sender).transfer(refundAmount);
        
        emit RefundIssued(campaignId, msg.sender, refundAmount);
    }

    function getCampaignContributions(uint256 campaignId) external view returns (Contribution[] memory) {
        return campaignContributions[campaignId];
    }

    function getCreatorCampaigns(address creator) external view returns (uint256[] memory) {
        return creatorCampaigns[creator];
    }

    function getContributorCampaigns(address contributor) external view returns (uint256[] memory) {
        return contributorCampaigns[contributor];
    }

    function getCampaignRewards(uint256 campaignId) external view returns (uint256[] memory, string[] memory) {
        Campaign storage campaign = campaigns[campaignId];
        return (campaign.rewardTiers, campaign.rewardDescriptions);
    }

    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        require(_platformFee <= 1000, "Fee too high"); // Max 10%
        platformFee = _platformFee;
    }

    function pauseCampaign(uint256 campaignId) external {
        require(campaigns[campaignId].creator == msg.sender, "Not campaign creator");
        campaigns[campaignId].isActive = false;
    }

    function resumeCampaign(uint256 campaignId) external {
        require(campaigns[campaignId].creator == msg.sender, "Not campaign creator");
        require(block.timestamp <= campaigns[campaignId].endTime, "Campaign ended");
        campaigns[campaignId].isActive = true;
    }
}
