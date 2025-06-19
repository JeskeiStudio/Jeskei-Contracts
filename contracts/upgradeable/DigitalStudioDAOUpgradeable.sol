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
// UPGRADEABLE DIGITAL STUDIO DAO
// =============================================================================

contract DigitalStudioDAOUpgradeable is 
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    
    struct StudioMember {
        bool isActive;
        uint256 joinTime;
        uint256 contributionScore;
        string role;
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
        uint256[] assetIds;
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
    
    AssetRegistryUpgradeable public assetRegistry;
    
    // New storage for future upgrades
    mapping(address => uint256) public memberReputationScore; // For reputation system
    mapping(uint256 => string[]) public projectTags; // For project categorization
    mapping(address => uint256[]) public memberProjects; // For member project history
    uint256[50] private __gap;
    
    event MemberAdded(address indexed member, string role);
    event ProjectCreated(uint256 indexed projectId, string name, uint256 budget);
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    
    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not a studio member");
        _;
    }
    
    modifier onlyFounder() {
        require(msg.sender == founder, "Not studio founder");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(string memory _studioName, address _assetRegistry) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        studioName = _studioName;
        founder = msg.sender;
        assetRegistry = AssetRegistryUpgradeable(_assetRegistry);
        
        members[msg.sender] = StudioMember({
            isActive: true,
            joinTime: block.timestamp,
            contributionScore: 100,
            role: "Founder"
        });
        
        memberList.push(msg.sender);
        memberCount = 1;
        memberReputationScore[msg.sender] = 100;
        
        emit MemberAdded(msg.sender, "Founder");
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyFounder {}

    function addMember(address newMember, string memory role) external onlyFounder {
        require(!members[newMember].isActive, "Already a member");
        require(newMember != address(0), "Invalid address");
        
        members[newMember] = StudioMember({
            isActive: true,
            joinTime: block.timestamp,
            contributionScore: 50,
            role: role
        });
        
        memberList.push(newMember);
        memberCount++;
        memberReputationScore[newMember] = 50;
        
        emit MemberAdded(newMember, role);
    }

    function createProject(
        string memory name,
        string memory description,
        uint256 budget,
        address[] memory contributors,
        uint256[] memory shares,
        string[] memory tags
    ) external onlyMember returns (uint256) {
        require(contributors.length == shares.length, "Array length mismatch");
        require(contributors.length > 0, "Need at least one contributor");
        
        for (uint i = 0; i < contributors.length; i++) {
            require(members[contributors[i]].isActive, "Contributor not a member");
        }
        
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
            memberProjects[contributors[i]].push(projectId);
        }
        
        projectTags[projectId] = tags;
        
        emit ProjectCreated(projectId, name, budget);
        return projectId;
    }

    function getProjectContributors(uint256 projectId) external view returns (address[] memory) {
        return projects[projectId].contributors;
    }

    function getProjectTags(uint256 projectId) external view returns (string[] memory) {
        return projectTags[projectId];
    }

    function getMemberProjects(address member) external view returns (uint256[] memory) {
        return memberProjects[member];
    }

    function updateMemberReputation(address member, uint256 newScore) external onlyFounder {
        require(members[member].isActive, "Not a member");
        memberReputationScore[member] = newScore;
    }

    receive() external payable {}
}
