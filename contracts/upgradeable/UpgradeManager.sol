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
import "./JeskeiProxyFactory.sol";

// =============================================================================
// UPGRADE MANAGER - Manages upgrade process and permissions
// =============================================================================

contract UpgradeManager is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    struct UpgradeProposal {
        string contractName;
        address newImplementation;
        string newVersion;
        string description;
        uint256 proposalTime;
        uint256 executionTime;
        bool executed;
        bool approved;
        address proposer;
    }
    
    mapping(uint256 => UpgradeProposal) public proposals;
    mapping(address => bool) public upgradeProposers;
    mapping(address => bool) public upgradeApprovers;
    
    uint256 public proposalCounter;
    uint256 public timelock; // Minimum time between proposal and execution
    JeskeiProxyFactory public proxyFactory;
    
    event UpgradeProposed(uint256 indexed proposalId, string contractName, address newImplementation);
    event UpgradeApproved(uint256 indexed proposalId);
    event UpgradeExecuted(uint256 indexed proposalId);
    event ProposerAdded(address indexed proposer);
    event ApproverAdded(address indexed approver);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _proxyFactory, uint256 _timelock) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        proxyFactory = JeskeiProxyFactory(_proxyFactory);
        timelock = _timelock;
        
        // Owner is initial proposer and approver
        upgradeProposers[msg.sender] = true;
        upgradeApprovers[msg.sender] = true;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    modifier onlyProposer() {
        require(upgradeProposers[msg.sender], "Not authorized proposer");
        _;
    }
    
    modifier onlyApprover() {
        require(upgradeApprovers[msg.sender], "Not authorized approver");
        _;
    }
    
    function addProposer(address proposer) external onlyOwner {
        upgradeProposers[proposer] = true;
        emit ProposerAdded(proposer);
    }
    
    function addApprover(address approver) external onlyOwner {
        upgradeApprovers[approver] = true;
        emit ApproverAdded(approver);
    }
    
    function proposeUpgrade(
        string memory contractName,
        address newImplementation,
        string memory newVersion,
        string memory description
    ) external onlyProposer returns (uint256) {
        require(newImplementation != address(0), "Invalid implementation");
        require(bytes(contractName).length > 0, "Contract name required");
        
        uint256 proposalId = proposalCounter++;
        
        proposals[proposalId] = UpgradeProposal({
            contractName: contractName,
            newImplementation: newImplementation,
            newVersion: newVersion,
            description: description,
            proposalTime: block.timestamp,
            executionTime: block.timestamp + timelock,
            executed: false,
            approved: false,
            proposer: msg.sender
        });
        
        emit UpgradeProposed(proposalId, contractName, newImplementation);
        return proposalId;
    }
    
    function approveUpgrade(uint256 proposalId) external onlyApprover {
        require(proposalId < proposalCounter, "Invalid proposal");
        require(!proposals[proposalId].executed, "Already executed");
        
        proposals[proposalId].approved = true;
        emit UpgradeApproved(proposalId);
    }
    
    function executeUpgrade(uint256 proposalId) external onlyApprover {
        require(proposalId < proposalCounter, "Invalid proposal");
        require(proposals[proposalId].approved, "Not approved");
        require(!proposals[proposalId].executed, "Already executed");
        require(block.timestamp >= proposals[proposalId].executionTime, "Timelock not expired");
        
        UpgradeProposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        
        // Execute upgrade through proxy factory
        proxyFactory.upgradeProxy(
            proposal.contractName,
            proposal.newImplementation,
            proposal.newVersion
        );
        
        emit UpgradeExecuted(proposalId);
    }
    
    function setTimelock(uint256 _timelock) external onlyOwner {
        require(_timelock >= 1 hours, "Timelock too short");
        require(_timelock <= 30 days, "Timelock too long");
        timelock = _timelock;
    }
    
    function getProposal(uint256 proposalId) external view returns (
        string memory contractName,
        address newImplementation,
        string memory newVersion,
        string memory description,
        uint256 executionTime,
        bool approved,
        bool executed
    ) {
        UpgradeProposal storage proposal = proposals[proposalId];
        return (
            proposal.contractName,
            proposal.newImplementation,
            proposal.newVersion,
            proposal.description,
            proposal.executionTime,
            proposal.approved,
            proposal.executed
        );
    }
}
