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
// PROXY FACTORY - Manages deployment and upgrades of all platform contracts
// =============================================================================

contract JeskeiProxyFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    struct ProxyInfo {
        address proxyAddress;
        address implementationAddress;
        string contractName;
        string version;
        uint256 deploymentTime;
        uint256 lastUpgrade;
        bool isActive;
    }
    
    mapping(string => ProxyInfo) public proxies;
    mapping(address => string) public proxyToName;
    mapping(address => bool) public authorizedUpgraders;
    
    string[] public contractNames;
    
    event ProxyDeployed(
        string indexed contractName,
        address indexed proxyAddress,
        address indexed implementationAddress,
        string version
    );
    
    event ProxyUpgraded(
        string indexed contractName,
        address indexed proxyAddress,
        address oldImplementation,
        address newImplementation,
        string newVersion
    );
    
    event UpgraderAuthorized(address indexed upgrader);
    event UpgraderRevoked(address indexed upgrader);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        // Factory owner is authorized upgrader by default
        authorizedUpgraders[msg.sender] = true;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    modifier onlyUpgrader() {
        require(authorizedUpgraders[msg.sender], "Not authorized upgrader");
        _;
    }
    
    function authorizeUpgrader(address upgrader) external onlyOwner {
        require(upgrader != address(0), "Invalid upgrader address");
        authorizedUpgraders[upgrader] = true;
        emit UpgraderAuthorized(upgrader);
    }
    
    function revokeUpgrader(address upgrader) external onlyOwner {
        authorizedUpgraders[upgrader] = false;
        emit UpgraderRevoked(upgrader);
    }
    
    function deployProxy(
        string memory contractName,
        address implementationAddress,
        bytes memory initData,
        string memory version
    ) external onlyUpgrader returns (address) {
        require(implementationAddress != address(0), "Invalid implementation");
        require(bytes(contractName).length > 0, "Contract name required");
        require(bytes(version).length > 0, "Version required");
        
        // Check if this is a new contract or upgrade
        bool isNewContract = proxies[contractName].proxyAddress == address(0);
        
        // Deploy new proxy
        ERC1967Proxy proxy = new ERC1967Proxy(implementationAddress, initData);
        address proxyAddress = address(proxy);
        
        // Update proxy info
        proxies[contractName] = ProxyInfo({
            proxyAddress: proxyAddress,
            implementationAddress: implementationAddress,
            contractName: contractName,
            version: version,
            deploymentTime: block.timestamp,
            lastUpgrade: block.timestamp,
            isActive: true
        });
        
        proxyToName[proxyAddress] = contractName;
        
        if (isNewContract) {
            contractNames.push(contractName);
        }
        
        emit ProxyDeployed(contractName, proxyAddress, implementationAddress, version);
        return proxyAddress;
    }
    
    function upgradeProxy(
        string memory contractName,
        address newImplementation,
        string memory newVersion
    ) external onlyUpgrader {
        require(proxies[contractName].proxyAddress != address(0), "Proxy not found");
        require(newImplementation != address(0), "Invalid implementation");
        require(proxies[contractName].isActive, "Proxy not active");
        
        address proxyAddress = proxies[contractName].proxyAddress;
        address oldImplementation = proxies[contractName].implementationAddress;
        
        // Perform upgrade
        IUpgradeableProxy(proxyAddress).upgradeToAndCall(newImplementation, "");
        
        // Update proxy info
        proxies[contractName].implementationAddress = newImplementation;
        proxies[contractName].version = newVersion;
        proxies[contractName].lastUpgrade = block.timestamp;
        
        emit ProxyUpgraded(contractName, proxyAddress, oldImplementation, newImplementation, newVersion);
    }
    
    function getProxy(string memory contractName) external view returns (ProxyInfo memory) {
        return proxies[contractName];
    }
    
    function getAllProxies() external view returns (string[] memory) {
        return contractNames;
    }
    
    function deactivateProxy(string memory contractName) external onlyOwner {
        require(proxies[contractName].proxyAddress != address(0), "Proxy not found");
        proxies[contractName].isActive = false;
    }
}

// Interface for upgradeable proxies
interface IUpgradeableProxy {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}
