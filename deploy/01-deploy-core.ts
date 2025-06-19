import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployCore: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { 
    deployer, 
    hostingTreasury, 
    platformTreasury, 
    adTreasury, 
    crowdfundingTreasury 
  } = await getNamedAccounts();

  console.log("Deploying Jeskei Core Contracts...");
  console.log("Deployer:", deployer);

  // Deploy DeploymentHelper first
  const deploymentHelper = await deploy("DeploymentHelper", {
    from: deployer,
    log: true,
    waitConfirmations: 1,
  });

  console.log("DeploymentHelper deployed to:", deploymentHelper.address);

  // Deploy the platform using DeploymentHelper
  const DeploymentHelper = await hre.ethers.getContractAt("DeploymentHelper", deploymentHelper.address);
  
  const config = {
    hostingTreasury,
    platformTreasury,
    adTreasury,
    crowdfundingTreasury,
    upgradeTimelock: 24 * 60 * 60, // 24 hours
  };

  console.log("Deploying platform with config:", config);

  const tx = await DeploymentHelper.deployPlatform(config);
  const receipt = await tx.wait();

  // Extract deployed addresses from events
  const event = receipt.events?.find(e => e.event === "PlatformDeployed");
  if (event) {
    console.log("Platform deployed successfully!");
    console.log("Proxy Factory:", event.args?.proxyFactory);
    console.log("Upgrade Manager:", event.args?.upgradeManager);
    console.log("Asset Registry:", event.args?.assetRegistry);
    console.log("Revenue Distributor:", event.args?.revenueDistributor);
    console.log("Performer Auth:", event.args?.performerAuth);
  }
};

export default deployCore;
deployCore.tags = ["Core", "All"];