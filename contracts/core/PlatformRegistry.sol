// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============================================================================
// PLATFORM REGISTRY - Central registry for all platform contracts
// =============================================================================

contract PlatformRegistry is Ownable {
    
    struct ContractInfo {
        address contractAddress;
        string name;
        string version;
        bool isActive;
        uint256 deploymentTime;
    }
    
    mapping(string => ContractInfo) public contracts;
    mapping(address => bool) public authorizedContracts;
    
    string[] public contractNames;
    
    event ContractRegistered(string name, address contractAddress, string version);
    event ContractDeactivated(string name, address contractAddress);
    event ContractAuthorized(address contractAddress);
    
    constructor() Ownable(msg.sender) {}
    
    function registerContract(
        string memory name,
        address contractAddress,
        string memory version
    ) external onlyOwner {
        require(contractAddress != address(0), "Invalid contract address");
        require(bytes(name).length > 0, "Name required");
        require(bytes(version).length > 0, "Version required");
        
        // If this is a new contract name, add to list
        if (contracts[name].contractAddress == address(0)) {
            contractNames.push(name);
        }
        
        contracts[name] = ContractInfo({
            contractAddress: contractAddress,
            name: name,
            version: version,
            isActive: true,
            deploymentTime: block.timestamp
        });
        
        authorizedContracts[contractAddress] = true;
        
        emit ContractRegistered(name, contractAddress, version);
        emit ContractAuthorized(contractAddress);
    }

    function deactivateContract(string memory name) external onlyOwner {
        require(contracts[name].contractAddress != address(0), "Contract not found");
        require(contracts[name].isActive, "Contract already inactive");
        
        contracts[name].isActive = false;
        authorizedContracts[contracts[name].contractAddress] = false;
        
        emit ContractDeactivated(name, contracts[name].contractAddress);
    }

    function getContract(string memory name) external view returns (
        address contractAddress,
        string memory version,
        bool isActive,
        uint256 deploymentTime
    ) {
        ContractInfo storage info = contracts[name];
        return (info.contractAddress, info.version, info.isActive, info.deploymentTime);
    }

    function getAllContracts() external view returns (string[] memory) {
        return contractNames;
    }

    function isAuthorized(address contractAddress) external view returns (bool) {
        return authorizedContracts[contractAddress];
    }
}
