// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./JeskeiProxyFactory.sol";
import "./UpgradeManager.sol";
import "./AssetRegistryUpgradeable.sol";
import "./RevenueDistributorUpgradeable.sol";
import "./PerformerAuthenticationUpgradeable.sol";

// ======================import "./RevenueDistributorUpgradeable.sol";=======================================================
// DEPLOYMENT SCRIPT HELPER
// =============================================================================

contract DeploymentHelper {
    
    struct DeploymentConfig {
        address hostingTreasury;
        address platformTreasury;
        address adTreasury;
        address crowdfundingTreasury;
        uint256 upgradeTimelock;
    }
    
    event PlatformDeployed(
        address proxyFactory,
        address upgradeManager,
        address assetRegistry,
        address revenueDistributor,
        address performerAuth
    );
    
    function deployPlatform(DeploymentConfig memory config) external returns (
        address proxyFactory,
        address upgradeManager,
        address assetRegistry,
        address revenueDistributor,
        address performerAuth
    ) {
        // Deploy proxy factory implementation
        JeskeiProxyFactory factoryImpl = new JeskeiProxyFactory();
        
        // Deploy proxy factory proxy
        bytes memory factoryInitData = abi.encodeWithSelector(
            JeskeiProxyFactory.initialize.selector
        );
        ERC1967Proxy factoryProxy = new ERC1967Proxy(address(factoryImpl), factoryInitData);
        proxyFactory = address(factoryProxy);
        
        // Deploy upgrade manager
        UpgradeManager upgradeManagerImpl = new UpgradeManager();
        bytes memory upgradeInitData = abi.encodeWithSelector(
            UpgradeManager.initialize.selector,
            proxyFactory,
            config.upgradeTimelock
        );
        ERC1967Proxy upgradeProxy = new ERC1967Proxy(address(upgradeManagerImpl), upgradeInitData);
        upgradeManager = address(upgradeProxy);
        
        // Deploy core contract implementations
        AssetRegistryUpgradeable assetImpl = new AssetRegistryUpgradeable();
        RevenueDistributorUpgradeable revenueImpl = new RevenueDistributorUpgradeable();
        PerformerAuthenticationUpgradeable performerImpl = new PerformerAuthenticationUpgradeable();
        
        // Deploy proxies through factory
        JeskeiProxyFactory factory = JeskeiProxyFactory(proxyFactory);
        
        // Asset Registry
        bytes memory assetInitData = abi.encodeWithSelector(
            AssetRegistryUpgradeable.initialize.selector,
            config.hostingTreasury
        );
        assetRegistry = factory.deployProxy(
            "AssetRegistry",
            address(assetImpl),
            assetInitData,
            "1.0.0"
        );
        
        // Revenue Distributor
        bytes memory revenueInitData = abi.encodeWithSelector(
            RevenueDistributorUpgradeable.initialize.selector,
            assetRegistry,
            config.platformTreasury
        );
        revenueDistributor = factory.deployProxy(
            "RevenueDistributor",
            address(revenueImpl),
            revenueInitData,
            "1.0.0"
        );
        
        // Performer Authentication
        bytes memory performerInitData = abi.encodeWithSelector(
            PerformerAuthenticationUpgradeable.initialize.selector
        );
        performerAuth = factory.deployProxy(
            "PerformerAuthentication",
            address(performerImpl),
            performerInitData,
            "1.0.0"
        );
        
        // Authorize upgrade manager as upgrader
        factory.authorizeUpgrader(upgradeManager);
        
        emit PlatformDeployed(
            proxyFactory,
            upgradeManager,
            assetRegistry,
            revenueDistributor,
            performerAuth
        );
    }
}
