// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============================================================================
// PERFORMER AUTHENTICATION - Identity verification system (OpenZeppelin v5)
// =============================================================================

contract PerformerAuthentication is Ownable, Pausable {
    
    struct PerformerProfile {
        bool isVerified;
        bytes32 identityHash; // Hash of identity document
        string publicKey; // For signing content
        uint256 verificationTime;
        string metadataURI; // Additional profile data
        uint256 reputationScore;
    }
    
    mapping(address => PerformerProfile) public performers;
    mapping(bytes32 => address) public identityHashToAddress;
    mapping(address => bool) public verifiers; // Addresses that can verify performers
    
    address[] public verifiedPerformers;
    
    event PerformerVerified(address indexed performer, bytes32 identityHash);
    event PerformerRevoked(address indexed performer);
    event VerifierAdded(address indexed verifier);
    
    constructor() Ownable(msg.sender) {
        verifiers[msg.sender] = true; // Contract owner is initial verifier
    }

    function addVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = true;
        emit VerifierAdded(verifier);
    }

    function removeVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = false;
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
            reputationScore: 100 // Starting reputation
        });
        
        identityHashToAddress[identityHash] = performer;
        verifiedPerformers.push(performer);
        
        emit PerformerVerified(performer, identityHash);
    }

    function revokePerformer(address performer) external {
        require(verifiers[msg.sender], "Not authorized verifier");
        require(performers[performer].isVerified, "Performer not verified");
        
        bytes32 identityHash = performers[performer].identityHash;
        delete performers[performer];
        delete identityHashToAddress[identityHash];
        
        // Remove from verified list
        for (uint i = 0; i < verifiedPerformers.length; i++) {
            if (verifiedPerformers[i] == performer) {
                verifiedPerformers[i] = verifiedPerformers[verifiedPerformers.length - 1];
                verifiedPerformers.pop();
                break;
            }
        }
        
        emit PerformerRevoked(performer);
    }

    function isVerifiedPerformer(address performer) external view returns (bool) {
        return performers[performer].isVerified;
    }

    function getPerformerVerificationHash(address performer) external view returns (bytes32) {
        return performers[performer].identityHash;
    }

    function getVerifiedPerformers() external view returns (address[] memory) {
        return verifiedPerformers;
    }

    function updateReputationScore(address performer, uint256 newScore) external {
        require(verifiers[msg.sender], "Not authorized verifier");
        require(performers[performer].isVerified, "Performer not verified");
        require(newScore <= 1000, "Score too high");
        
        performers[performer].reputationScore = newScore;
    }
}