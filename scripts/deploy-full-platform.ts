import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy DeploymentHelper
  const DeploymentHelper = await ethers.getContractFactory("DeploymentHelper");
  const deploymentHelper = await DeploymentHelper.deploy();
  await deploymentHelper.deployed();

  console.log("DeploymentHelper deployed to:", deploymentHelper.address);

  // Configuration
  const config = {
    hostingTreasury: process.env.HOSTING_TREASURY || deployer.address,
    platformTreasury: process.env.PLATFORM_TREASURY || deployer.address,
    adTreasury: process.env.AD_TREASURY || deployer.address,
    crowdfundingTreasury: process.env.CROWDFUNDING_TREASURY || deployer.address,
    upgradeTimelock: 24 * 60 * 60, // 24 hours
  };

  // Deploy platform
  const tx = await deploymentHelper.deployPlatform(config);
  const receipt = await tx.wait();

  console.log("Platform deployment transaction:", tx.hash);
  console.log("Gas used:", receipt.gasUsed.toString());

  // Save deployment addresses
  const fs = require('fs');
  const deploymentData = {
    network: (await ethers.provider.getNetwork()).name,
    deploymentHelper: deploymentHelper.address,
    deployer: deployer.address,
    config,
    transaction: tx.hash,
    gasUsed: receipt.gasUsed.toString(),
    timestamp: new Date().toISOString(),
  };

  fs.writeFileSync(
    `deployments/${deploymentData.network}-deployment.json`,
    JSON.stringify(deploymentData, null, 2)
  );

  console.log("Deployment data saved to deployments folder");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});