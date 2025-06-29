import { ethers } from "hardhat";
import * as hre from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Master deploy script – spins up **every upgradeable module currently in the
 * repo** so the front‑end team can consume a single JSON of proxy addresses.
 *
 * If you later add more contracts, just extend the `MODULES` array. Each entry
 * defines:
 *   ‑ `label`                Human‑readable name + proxy key in /deployments
 *   ‑ `impl`                 Solidity factory name of the upgradeable impl.
 *   ‑ `init`                 Initialize selector string.
 *   ‑ `args(hre, addrs)`     Function returning constructor‑style args. It
 *                            receives the HardhatRuntimeEnvironment and a
 *                            map of addresses already deployed during this
 *                            run (so you can reference AssetRegistry, etc.).
 */

const DAY = 24 * 60 * 60;
const CONFIRMATIONS = hre.network.name === "hardhat" ? 1 : 5; // wait for Etherscan propagation

// --------------------------------------------------------------------
// Helper: attempt Etherscan verify (skips when local or missing API key)
// --------------------------------------------------------------------
async function verifyIfLive(address: string, constructorArguments: unknown[] = []) {
  if (hre.network.name === "hardhat" || !process.env.ETHERSCAN_API_KEY) return;
  try {
    await hre.run("verify:verify", { address, constructorArguments });
    console.log(`      ✔︎ verified ${address}`);
  } catch (err: any) {
    if (err.message?.toLowerCase().includes("already verified")) {
      console.log(`      • already verified ${address}`);
    } else {
      console.log(`      ⚠︎ verify failed ${address}: ${err.message}`);
    }
  }
}

type Module = {
  label: string;
  impl: string;
  init: string;
  args: (addrs: Record<string, string>) => unknown[];
};

const MODULES: Module[] = [
  {
    label: "AssetRegistry",
    impl: "AssetRegistryUpgradeable",
    init: "initialize",
    args: (a) => [a.hostingTreasury],
  },
  {
    label: "RevenueDistributor",
    impl: "RevenueDistributorUpgradeable",
    init: "initialize",
    args: (a) => [a.AssetRegistry, a.platformTreasury],
  },
  {
    label: "PerformerAuthentication",
    impl: "PerformerAuthenticationUpgradeable",
    init: "initialize",
    args: () => [],
  },
  // ---- Additional modules ----
  {
    label: "AdvertisingEngine",
    impl: "AdvertisingEngineUpgradeable",
    init: "initialize",
    args: (a) => [a.AssetRegistry],
  },
  {
    label: "ContentAccess",
    impl: "ContentAccessUpgradeable",
    init: "initialize",
    args: (a) => [a.AssetRegistry, a.PerformerAuthentication],
  },
  {
    label: "DigitalStudioDAO",
    impl: "DigitalStudioDAOUpgradeable",
    init: "initialize",
    args: (a) => [a.AssetRegistry, a.PerformerAuthentication],
  },
  // Non‑upgradeable CommunityGovernance (immutable implementation)
  // Deployed as a plain contract (not proxy)
];

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { save, log } = deployments;

  const named = await getNamedAccounts();
  const addrs: Record<string, string> = {
    deployer: named.deployer,
    hostingTreasury: named.hostingTreasury,
    platformTreasury: named.platformTreasury,
    adTreasury: named.adTreasury,
    crowdfundingTreasury: named.crowdfundingTreasury,
  };

  log(`
▶︎ Deploying full Jeskei stack…`);
  log(`   deployer: ${addrs.deployer}`);

  /* -------------------------------------------------------------------- */
  /* Helper: deploy impl + UUPS proxy                                     */
  /* -------------------------------------------------------------------- */

  async function deployUUPS(
    label: string,
    implFactoryName: string,
    initSelector: string,
    initArgs: unknown[]
  ) {
    const ImplF = await ethers.getContractFactory(implFactoryName);
    const impl = await ImplF.deploy();
    await impl.waitForDeployment();
    if (impl.deploymentTransaction()) await impl.deploymentTransaction()!.wait(CONFIRMATIONS);
    // wait extra confirmations so Etherscan indexes bytecode
    if (impl.deploymentTransaction()) await impl.deploymentTransaction()!.wait(CONFIRMATIONS);
    const implAddr = await impl.getAddress();
    log(`   ${label} impl   → ${implAddr}`);
    await verifyIfLive(implAddr);

    const initData = ImplF.interface.encodeFunctionData(initSelector, initArgs);
    const ProxyF = await ethers.getContractFactory("ERC1967Proxy");
    const proxy = await ProxyF.deploy(implAddr, initData);
    await proxy.waitForDeployment();
    if (proxy.deploymentTransaction()) await proxy.deploymentTransaction()!.wait(CONFIRMATIONS);
    const proxyAddr = await proxy.getAddress();
    log(`   ${label} proxy  → ${proxyAddr}`);
    await verifyIfLive(proxyAddr, [implAddr, initData]);

    await save(label, {
      abi: ImplF.interface.format("json") as string[],
      address: proxyAddr,
    });

    addrs[label] = proxyAddr; // expose for later module args
  }

  /* -------------------------------------------------------------------- */
  /* 1. Infrastructure: ProxyFactory + UpgradeManager                     */
  /* -------------------------------------------------------------------- */

  await deployUUPS("JeskeiProxyFactory", "JeskeiProxyFactory", "initialize", []);
  await deployUUPS("UpgradeManager", "UpgradeManager", "initialize", [addrs.JeskeiProxyFactory, DAY]);

  /* Attach factory proxy with correct ABI */
  const ProxyFactoryABI = (await ethers.getContractFactory("JeskeiProxyFactory")).interface;
  const proxyFactory = new ethers.Contract(addrs.JeskeiProxyFactory, ProxyFactoryABI, await ethers.getSigner(addrs.deployer));

  /* -------------------------------------------------------------------- */
  /* 2. Deploy every upgradeable module via ProxyFactory                   */
  /* -------------------------------------------------------------------- */

  for (const mod of MODULES) {
    const ImplF = await ethers.getContractFactory(mod.impl);
    const impl = await ImplF.deploy();
    await impl.waitForDeployment();
    if (impl.deploymentTransaction()) await impl.deploymentTransaction()!.wait(CONFIRMATIONS);
    const implAddr = await impl.getAddress();

    const initArgs = mod.args(addrs);
    const initData = ImplF.interface.encodeFunctionData(mod.init, initArgs);

    const deployFn = proxyFactory.getFunction("deployProxy");
    const proxyAddr: string = await deployFn.staticCall(mod.label, implAddr, initData, "1.0.0");
    const txDeploy = await deployFn(mod.label, implAddr, initData, "1.0.0");
    await txDeploy.wait(CONFIRMATIONS);

    log(`   ${mod.label} proxy  → ${proxyAddr}`);
    await verifyIfLive(implAddr);
    await verifyIfLive(proxyAddr, [implAddr, initData]);
    await save(mod.label, {
      abi: ImplF.interface.format("json") as string[],
      address: proxyAddr,
    });

    addrs[mod.label] = proxyAddr;
  }

  /* -------------------------------------------------------------------- */
  /* 3. Non‑upgradeable CommunityGovernance (optional)                     */
  /* -------------------------------------------------------------------- */

    const GovF = await ethers.getContractFactory("CommunityGovernance");
  // constructor(address _assetRegistry, address _revenueDistributor)
  const governance = await GovF.deploy(addrs.AssetRegistry, addrs.RevenueDistributor);
  await governance.waitForDeployment();
  if (governance.deploymentTransaction()) await governance.deploymentTransaction()!.wait(CONFIRMATIONS);
  const govAddr = await governance.getAddress();
  log(`   CommunityGovernance impl → ${govAddr}`);
  await verifyIfLive(govAddr, [addrs.AssetRegistry, addrs.RevenueDistributor]);
  await save("CommunityGovernance", {
    abi: GovF.interface.format("json") as string[],
    address: govAddr,
  });

  /* -------------------------------------------------------------------- */
  /* 4. Set UpgradeManager as global upgrader                              */
  /* -------------------------------------------------------------------- */

  const upgradeMgr = addrs.UpgradeManager;
  await (await proxyFactory.authorizeUpgrader(upgradeMgr)).wait();
  log("   UpgradeManager authorised as upgrader ✅");

  log("Jeskei full stack deployed ✔︎");
};

export default func;
func.tags = ["FullStack"];
