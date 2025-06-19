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
// UPGRADEABLE PERFORMER AUTHENTICATION
// =============================================================================

contract PerformerAuthenticationUpgradeable is 
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    
    struct PerformerProfile {
        bool isVerified;
        bytes32 identityHash;
        string publicKey;
        uint256 verificationTime;
        string metadataURI;
        uint256 reputationScore;
    }
    
    mapping(address => PerformerProfile) public performers;
    mapping(bytes32 => address) public identityHashToAddress;
    mapping(address => bool) public verifiers;
    
    address[] public verifiedPerformers;
    
    // New storage for future upgrades
    mapping(address => uint256) public performerTier; // For tiered verification
    mapping(address => string[]) public performerSkills; // For skill verification
    uint256[50] private __gap;
    
    event PerformerVerified(address indexed performer, bytes32 identityHash);
    event PerformerRevoked(address indexed performer);
    event VerifierAdded(address indexed verifier);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        verifiers[msg.sender] = true;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function addVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = true;
        emit VerifierAdded(verifier);
    }

    function verifyPerformer(
        address performer,
        bytes32 identityHash,
        string memory publicKey,
        string memory metadataURI
    ) external whenNotPaused {
        require(verifiers[msg.sender], "Not authorized verifier");
        require(performer != address(0), "Invalid performer address");
        require(identityHashToAddress[identityHash] == address(0), "Identity already used");
        
        performers[performer] = PerformerProfile({
            isVerified: true,
            identityHash: identityHash,
            publicKey: publicKey,
            verificationTime: block.timestamp,
            metadataURI: metadataURI,
            reputationScore: 100
        });
        
        identityHashToAddress[identityHash] = performer;
        verifiedPerformers.push(performer);
        
        emit PerformerVerified(performer, identityHash);
    }

    function isVerifiedPerformer(address performer) external view returns (bool) {
        return performers[performer].isVerified;
    }

    function getVerifiedPerformers() external view returns (address[] memory) {
        return verifiedPerformers;
    }

    // Future upgrade functions
    function setPerformerTier(address performer, uint256 tier) external {
        require(verifiers[msg.sender], "Not authorized verifier");
        require(performers[performer].isVerified, "Performer not verified");
        performerTier[performer] = tier;
    }

    function addPerformerSkill(address performer, string memory skill) external {
        require(verifiers[msg.sender], "Not authorized verifier");
        require(performers[performer].isVerified, "Performer not verified");
        performerSkills[performer].push(skill);
    }
}