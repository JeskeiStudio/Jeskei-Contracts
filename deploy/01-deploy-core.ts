import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";


/**
 * TypeScript deploy script that performs the same orchestration previously
 * handled by the oversized on‑chain `DeploymentHelper`.
 *
 * Works with **ethers.js v6** (note the `waitForDeployment()` + `getAddress()`
 * pattern and the lack of `.address` / `.deployed()` helpers from v5).
 */

const DAY = 24 * 60 * 60; // in seconds

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { save, log } = deployments;

  const {
    deployer,
    hostingTreasury,
    platformTreasury,
    /* adTreasury, crowdfundingTreasury – not used in constructor args yet */
  } = await getNamedAccounts();

  log(`
▶︎ Deploying Jeskei platform…`);
  log(`   deployer: ${deployer}`);

  /* ---------------------------------------------------------------------- */
  /* 0.  Helper to deploy an impl + proxy in one go                          */
  /* ---------------------------------------------------------------------- */

  const ERC1967ProxyF = await ethers.getContractFactory("ERC1967Proxy");

  async function deployUUPS(
    name: string,
    implFactoryName: string,
    initSelector: string,
    initArgs: readonly unknown[]
  ) {
    const ImplF = await ethers.getContractFactory(implFactoryName);
    const impl = await ImplF.deploy();
    await impl.waitForDeployment();
    const implAddr = await impl.getAddress();
    log(`   ${name} impl   → ${implAddr}`);

    const initData = impl.interface.encodeFunctionData(initSelector, initArgs);
    const proxy = await ERC1967ProxyF.deploy(implAddr, initData);
    await proxy.waitForDeployment();
    const proxyAddr = await proxy.getAddress();
    log(`   ${name} proxy  → ${proxyAddr}`);

    await save(name, {
      abi: ImplF.interface.format("json") as string[],
      address: proxyAddr,
    });

    return { implAddr, proxyAddr };
  }

  /* ---------------------------------------------------------------------- */
  /* 1. JeskeiProxyFactory (UUPS)                                            */
  /* ---------------------------------------------------------------------- */

  const { proxyAddr: proxyFactoryAddr } = await deployUUPS(
    "JeskeiProxyFactory",
    "JeskeiProxyFactory",
    "initialize",
    []
  );

  /* ---------------------------------------------------------------------- */
  /* 2. UpgradeManager (UUPS)                                               */
  /* ---------------------------------------------------------------------- */

  const { proxyAddr: upgradeManagerAddr } = await deployUUPS(
    "UpgradeManager",
    "UpgradeManager",
    "initialize",
    [proxyFactoryAddr, DAY]
  );

  /* ---------------------------------------------------------------------- */
  /* 3. Deploy core modules via JeskeiProxyFactory                           */
  /* ---------------------------------------------------------------------- */

    // Connect to proxy with correct ABI (attach implementation interface to proxy address)
  const JeskeiProxyFactoryF = await ethers.getContractFactory("JeskeiProxyFactory");
  const proxyFactory = JeskeiProxyFactoryF.attach(proxyFactoryAddr).connect(
    await ethers.getSigner(deployer)
  );

    async function deployViaFactory(
    label: string,
    implFactoryName: string,
    initSelector: string,
    initArgs: readonly unknown[]
  ) {
    const ImplF = await ethers.getContractFactory(implFactoryName);
    const impl = await ImplF.deploy();
    await impl.waitForDeployment();
    const implAddr = await impl.getAddress();

    const initData = impl.interface.encodeFunctionData(initSelector, initArgs);

        // -- ethers v6: obtain return value via .staticCall on the function fragment
    const deployFn = proxyFactory.getFunction("deployProxy");
    const proxyAddr: string = await deployFn.staticCall(label, implAddr, initData, "1.0.0");

    const txResponse = await deployFn(label, implAddr, initData, "1.0.0");
    await txResponse.wait();

    log(`   ${label} proxy  → ${proxyAddr}`);

    await save(label, {
      abi: ImplF.interface.format("json") as string[],
      address: proxyAddr,
    });

    return proxyAddr;
  }

  // AssetRegistryUpgradeable
  const assetRegistryAddr = await deployViaFactory(
    "AssetRegistry",
    "AssetRegistryUpgradeable",
    "initialize",
    [hostingTreasury]
  );

  // RevenueDistributorUpgradeable
  await deployViaFactory(
    "RevenueDistributor",
    "RevenueDistributorUpgradeable",
    "initialize",
    [assetRegistryAddr, platformTreasury]
  );

  // PerformerAuthenticationUpgradeable
  await deployViaFactory(
    "PerformerAuthentication",
    "PerformerAuthenticationUpgradeable",
    "initialize",
    []
  );

  /* ---------------------------------------------------------------------- */
  /* 4. Authorise UpgradeManager as upgrader                                */
  /* ---------------------------------------------------------------------- */

  await (await proxyFactory.authorizeUpgrader(upgradeManagerAddr)).wait();
  log("   UpgradeManager authorised as upgrader ✅");

  log("Jeskei platform deployed ✔︎");
};

export default func;
func.tags = ["Core", "All"];
