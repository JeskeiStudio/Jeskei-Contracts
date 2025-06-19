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
// DIGITAL STUDIO DAO - Collaborative content creation
// =============================================================================

contract DigitalStudioDAO is ReentrancyGuard, Pausable {
    
    struct StudioMember {
        bool isActive;
        uint256 joinTime;
        uint256 contributionScore;
        string role; // "director", "producer", "actor", etc.
    }
    
    struct Project {
        string name;
        string description;
        uint256 budget;
        uint256 raised;
        bool isActive;
        uint256 creationTime;
        address[] contributors;
        mapping(address => uint256) contributorShares;
        uint256[] assetIds; // Associated NFTs
    }
    
    struct Proposal {
        string description;
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        ProposalType proposalType;
        address targetAddress;
        uint256 targetValue;
        bytes targetData;
    }
    
    enum ProposalType { AddMember, RemoveMember, ProjectFunding, General }
    
    string public studioName;
    address public founder;
    
    mapping(address => StudioMember) public members;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    address[] public memberList;
    uint256 public projectCounter;
    uint256 public proposalCounter;
    uint256 public memberCount;
    
    AssetRegistry public assetRegistry;
    
    event MemberAdded(address indexed member, string role);
    event MemberRemoved(address indexed member);
    event ProjectCreated(uint256 indexed projectId, string name, uint256 budget);
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address voter, bool support);
    
    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not a studio member");
        _;
    }
    
    modifier onlyFounder() {
        require(msg.sender == founder, "Not studio founder");
        _;
    }
    
    constructor(
        string memory _studioName,
        address _assetRegistry
    ) {
        studioName = _studioName;
        founder = msg.sender;
        assetRegistry = AssetRegistry(_assetRegistry);
        
        // Add founder as first member
        members[msg.sender] = StudioMember({
            isActive: true,
            joinTime: block.timestamp,
            contributionScore: 100,
            role: "Founder"
        });
        
        memberList.push(msg.sender);
        memberCount = 1;
        
        emit MemberAdded(msg.sender, "Founder");
    }

    function addMember(address newMember, string memory role) external onlyFounder {
        require(!members[newMember].isActive, "Already a member");
        require(newMember != address(0), "Invalid address");
        
        members[newMember] = StudioMember({
            isActive: true,
            joinTime: block.timestamp,
            contributionScore: 50, // Starting score
            role: role
        });
        
        memberList.push(newMember);
        memberCount++;
        
        emit MemberAdded(newMember, role);
    }

    function createProject(
        string memory name,
        string memory description,
        uint256 budget,
        address[] memory contributors,
        uint256[] memory shares
    ) external onlyMember returns (uint256) {
        require(contributors.length == shares.length, "Array length mismatch");
        require(contributors.length > 0, "Need at least one contributor");
        
        // Verify all contributors are members
        for (uint i = 0; i < contributors.length; i++) {
            require(members[contributors[i]].isActive, "Contributor not a member");
        }
        
        // Verify shares sum to 100%
        uint256 totalShares = 0;
        for (uint i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 10000, "Shares must equal 100%");
        
        uint256 projectId = projectCounter++;
        Project storage newProject = projects[projectId];
        
        newProject.name = name;
        newProject.description = description;
        newProject.budget = budget;
        newProject.raised = 0;
        newProject.isActive = true;
        newProject.creationTime = block.timestamp;
        newProject.contributors = contributors;
        
        for (uint i = 0; i < contributors.length; i++) {
            newProject.contributorShares[contributors[i]] = shares[i];
        }
        
        emit ProjectCreated(projectId, name, budget);
        return projectId;
    }

    function addAssetToProject(uint256 projectId, uint256 assetId) external onlyMember {
        require(projects[projectId].isActive, "Project not active");
        require(assetRegistry.ownerOf(assetId) == msg.sender, "Not asset owner");
        
        projects[projectId].assetIds.push(assetId);
    }

    function createProposal(
        string memory description,
        ProposalType proposalType,
        address targetAddress,
        uint256 targetValue,
        bytes memory targetData
    ) external onlyMember returns (uint256) {
        uint256 proposalId = proposalCounter++;
        
        proposals[proposalId] = Proposal({
            description: description,
            proposer: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + 7 days, // 1 week voting period
            executed: false,
            proposalType: proposalType,
            targetAddress: targetAddress,
            targetValue: targetValue,
            targetData: targetData
        });
        
        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyMember {
        require(proposalId < proposalCounter, "Invalid proposal");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposals[proposalId].votesFor++;
        } else {
            proposals[proposalId].votesAgainst++;
        }
        
        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external onlyMember {
        require(proposalId < proposalCounter, "Invalid proposal");
        require(block.timestamp > proposals[proposalId].deadline, "Voting still active");
        require(!proposals[proposalId].executed, "Already executed");
        require(proposals[proposalId].votesFor > proposals[proposalId].votesAgainst, "Proposal rejected");
        
        proposals[proposalId].executed = true;
        
        // Execute based on proposal type
        if (proposals[proposalId].proposalType == ProposalType.General) {
            // Execute arbitrary call
            (bool success,) = proposals[proposalId].targetAddress.call{
                value: proposals[proposalId].targetValue
            }(proposals[proposalId].targetData);
            require(success, "Proposal execution failed");
        }
        
        emit ProposalExecuted(proposalId);
    }

    function getProjectContributors(uint256 projectId) external view returns (address[] memory) {
        return projects[projectId].contributors;
    }

    function getProjectAssets(uint256 projectId) external view returns (uint256[] memory) {
        return projects[projectId].assetIds;
    }

    function getMembers() external view returns (address[] memory) {
        return memberList;
    }

    receive() external payable {
        // Allow studio to receive funds
    }
}
