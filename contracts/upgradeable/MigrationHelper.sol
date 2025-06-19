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
// MIGRATION HELPER - Assists with data migration during upgrades
// =============================================================================

contract MigrationHelper is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    struct MigrationBatch {
        uint256 startId;
        uint256 endId;
        bool completed;
        uint256 timestamp;
    }
    
    mapping(string => mapping(uint256 => MigrationBatch)) public migrationBatches;
    mapping(string => uint256) public migrationProgress;
    mapping(string => bool) public migrationCompleted;
    
    event MigrationStarted(string indexed contractName, uint256 totalItems);
    event BatchMigrated(string indexed contractName, uint256 batchId, uint256 startId, uint256 endId);
    event MigrationCompleted(string indexed contractName);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function startMigration(string memory contractName, uint256 totalItems) external onlyOwner {
        require(!migrationCompleted[contractName], "Migration already completed");
        migrationProgress[contractName] = 0;
        emit MigrationStarted(contractName, totalItems);
    }
    
    function migrateBatch(
        string memory contractName,
        uint256 batchId,
        uint256 startId,
        uint256 endId
    ) external onlyOwner {
        require(!migrationBatches[contractName][batchId].completed, "Batch already migrated");
        
        migrationBatches[contractName][batchId] = MigrationBatch({
            startId: startId,
            endId: endId,
            completed: true,
            timestamp: block.timestamp
        });
        
        migrationProgress[contractName] = endId;
        
        emit BatchMigrated(contractName, batchId, startId, endId);
    }
    
    function completeMigration(string memory contractName) external onlyOwner {
        require(!migrationCompleted[contractName], "Already completed");
        migrationCompleted[contractName] = true;
        emit MigrationCompleted(contractName);
    }
    
    function isMigrationCompleted(string memory contractName) external view returns (bool) {
        return migrationCompleted[contractName];
    }
    
    function getMigrationProgress(string memory contractName) external view returns (uint256) {
        return migrationProgress[contractName];
    }
}