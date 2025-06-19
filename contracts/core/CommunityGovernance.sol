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
// GOVERNANCE - Community governance without tokens
// =============================================================================

contract CommunityGovernance is Ownable, Pausable {
    
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        ProposalCategory category;
        uint256 votingPower; // Based on contribution to platform
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        bytes executionData;
        address targetContract;
    }
    
    struct Vote {
        bool hasVoted;
        bool support;
        uint256 weight;
        string reason;
    }
    
    enum ProposalCategory { PlatformFee, FeatureRequest, Partnership, GeneralGovernance }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256) public userVotingPower;
    mapping(address => bool) public councilMembers;
    
    address[] public councilMembersList;
    uint256 public proposalCounter;
    uint256 public votingPeriod = 7 days;
    uint256 public minVotingPower = 100; // Minimum power to create proposals
    
    AssetRegistry public assetRegistry;
    RevenueDistributor public revenueDistributor;
    
    event ProposalCreated(uint256 indexed proposalId, address proposer, string title);
    event VoteCast(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event CouncilMemberAdded(address indexed member);
    event CouncilMemberRemoved(address indexed member);
    
    modifier onlyCouncil() {
        require(councilMembers[msg.sender], "Not a council member");
        _;
    }
    
    constructor(address _assetRegistry, address _revenueDistributor) Ownable(msg.sender) {
        assetRegistry = AssetRegistry(_assetRegistry);
        revenueDistributor = RevenueDistributor(_revenueDistributor);
        
        // Add contract owner to council initially
        councilMembers[msg.sender] = true;
        councilMembersList.push(msg.sender);
    }

    function addCouncilMember(address member) external onlyOwner {
        require(!councilMembers[member], "Already council member");
        require(member != address(0), "Invalid address");
        
        councilMembers[member] = true;
        councilMembersList.push(member);
        
        emit CouncilMemberAdded(member);
    }

    function removeCouncilMember(address member) external onlyOwner {
        require(councilMembers[member], "Not a council member");
        
        councilMembers[member] = false;
        
        // Remove from list
        for (uint i = 0; i < councilMembersList.length; i++) {
            if (councilMembersList[i] == member) {
                councilMembersList[i] = councilMembersList[councilMembersList.length - 1];
                councilMembersList.pop();
                break;
            }
        }
        
        emit CouncilMemberRemoved(member);
    }

    function updateVotingPower(address user) public {
        // Calculate voting power based on platform contributions
        uint256[] memory userAssets = assetRegistry.getCreatorAssets(user);
        uint256 totalHostingPaid = 0;
        
        for (uint i = 0; i < userAssets.length; i++) {
            (, , , , , , , uint256 hostingFees, , ,) = assetRegistry.assets(userAssets[i]);
            totalHostingPaid += hostingFees;
        }
        
        // Voting power based on hosting fees paid (converted to points)
        // Plus bonus for council membership
        uint256 basePower = totalHostingPaid / 1 ether; // 1 point per ETH spent
        uint256 councilBonus = councilMembers[user] ? 100 : 0;
        
        userVotingPower[user] = basePower + councilBonus;
    }

    function createProposal(
        string memory title,
        string memory description,
        ProposalCategory category,
        address targetContract,
        bytes memory executionData
    ) external whenNotPaused returns (uint256) {
        updateVotingPower(msg.sender);
        require(userVotingPower[msg.sender] >= minVotingPower, "Insufficient voting power");
        require(bytes(title).length > 0, "Title required");
        require(bytes(description).length > 0, "Description required");
        
        uint256 proposalId = proposalCounter++;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            category: category,
            votingPower: userVotingPower[msg.sender],
            votesFor: 0,
            votesAgainst: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            executed: false,
            passed: false,
            executionData: executionData,
            targetContract: targetContract
        });
        
        emit ProposalCreated(proposalId, msg.sender, title);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support, string memory reason) external whenNotPaused {
        require(proposalId < proposalCounter, "Invalid proposal");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting period ended");
        require(!votes[proposalId][msg.sender].hasVoted, "Already voted");
        
        updateVotingPower(msg.sender);
        require(userVotingPower[msg.sender] > 0, "No voting power");
        
        votes[proposalId][msg.sender] = Vote({
            hasVoted: true,
            support: support,
            weight: userVotingPower[msg.sender],
            reason: reason
        });
        
        if (support) {
            proposals[proposalId].votesFor += userVotingPower[msg.sender];
        } else {
            proposals[proposalId].votesAgainst += userVotingPower[msg.sender];
        }
        
        emit VoteCast(proposalId, msg.sender, support, userVotingPower[msg.sender]);
    }

    function executeProposal(uint256 proposalId) external onlyCouncil {
        require(proposalId < proposalCounter, "Invalid proposal");
        require(block.timestamp > proposals[proposalId].endTime, "Voting still active");
        require(!proposals[proposalId].executed, "Already executed");
        
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        
        // Determine if proposal passed (simple majority by voting power)
        proposal.passed = proposal.votesFor > proposal.votesAgainst;
        
        // Execute if passed and has execution data
        if (proposal.passed && proposal.executionData.length > 0) {
            (bool success,) = proposal.targetContract.call(proposal.executionData);
            require(success, "Execution failed");
        }
        
        emit ProposalExecuted(proposalId, proposal.passed);
    }

    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory title,
        string memory description,
        ProposalCategory category,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed,
        bool passed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.category,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.endTime,
            proposal.executed,
            proposal.passed
        );
    }

    function getCouncilMembers() external view returns (address[] memory) {
        return councilMembersList;
    }

    function setVotingPeriod(uint256 _votingPeriod) external onlyOwner {
        require(_votingPeriod >= 1 days && _votingPeriod <= 30 days, "Invalid period");
        votingPeriod = _votingPeriod;
    }

    function setMinVotingPower(uint256 _minVotingPower) external onlyOwner {
        minVotingPower = _minVotingPower;
    }
}