import { expect } from "chai";
import { ethers } from "hardhat";
import { AssetRegistryUpgradeable } from "../../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("AssetRegistry", function () {
  let assetRegistry: AssetRegistryUpgradeable;
  let owner: HardhatEthersSigner;
  let creator: HardhatEthersSigner;
  let hostingTreasury: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, creator, hostingTreasury] = await ethers.getSigners();

    try {
      // Deploy implementation contract
      const AssetRegistryFactory = await ethers.getContractFactory("AssetRegistryUpgradeable");
      const implementation = await AssetRegistryFactory.deploy();
      await implementation.waitForDeployment();
      
      // Deploy ERC1967Proxy
      const ERC1967ProxyFactory = await ethers.getContractFactory("ERC1967Proxy");
      
      // Encode initialization data
      const initData = AssetRegistryFactory.interface.encodeFunctionData(
        "initialize", 
        [hostingTreasury.address]
      );
      
      // Deploy proxy
      const proxy = await ERC1967ProxyFactory.deploy(
        await implementation.getAddress(), 
        initData
      );
      await proxy.waitForDeployment();
      
      // Attach the implementation ABI to the proxy address
      assetRegistry = AssetRegistryFactory.attach(
        await proxy.getAddress()
      ) as AssetRegistryUpgradeable;
      
    } catch (error) {
      console.log("Setup error:", error);
      throw error;
    }
  });

  describe("Asset Creation", function () {
    it("Should create an asset with hosting fee", async function () {
      const hostingFee = ethers.parseEther("0.01");
      
      const tx = await assetRegistry.connect(creator).createAsset(
        "QmTest123",
        "https://metadata.uri",
        "video",
        "ipfs",
        false,
        ethers.parseEther("0.1"),
        { value: hostingFee }
      );

      await expect(tx)
        .to.emit(assetRegistry, "AssetCreated")
        .withArgs(0, creator.address, "QmTest123", "video", ethers.parseEther("0.1"));

      const asset = await assetRegistry.assets(0);
      expect(asset.creator).to.equal(creator.address);
      expect(asset.contentHash).to.equal("QmTest123");
    });

    it("Should distribute hosting fees correctly", async function () {
      const hostingFee = ethers.parseEther("0.01");
      const platformFeeRate = await assetRegistry.platformHostingFee();
      const expectedPlatformFee = hostingFee * platformFeeRate / 100n;
      const expectedCreatorFee = hostingFee - expectedPlatformFee;

      await assetRegistry.connect(creator).createAsset(
        "QmTest123",
        "https://metadata.uri",
        "video",
        "ipfs",
        false,
        ethers.parseEther("0.1"),
        { value: hostingFee }
      );

      const creatorBalance = await assetRegistry.hostingBalance(creator.address);
      const treasuryBalance = await assetRegistry.hostingBalance(hostingTreasury.address);

      expect(creatorBalance).to.equal(expectedCreatorFee);
      expect(treasuryBalance).to.equal(expectedPlatformFee);
    });
  });

  describe("Contributors", function () {
    it("Should add contributors with revenue shares", async function () {
      // Create asset first
      await assetRegistry.connect(creator).createAsset(
        "QmTest123",
        "https://metadata.uri",
        "video",
        "ipfs",
        false,
        ethers.parseEther("0.1"),
        { value: ethers.parseEther("0.01") }
      );

      // Add contributor
      await assetRegistry.connect(creator).addContributor(
        0,
        owner.address,
        2000, // 20%
        "actor"
      );

      const contributors = await assetRegistry.getAssetContributors(0);
      expect(contributors.length).to.equal(1);
      expect(contributors[0].contributorAddress).to.equal(owner.address);
      expect(contributors[0].sharePercentage).to.equal(2000);
      expect(contributors[0].role).to.equal("actor");
    });
  });

  describe("Basic functionality", function () {
    it("Should have correct initial state", async function () {
      expect(await assetRegistry.platformHostingFee()).to.equal(15);
      expect(await assetRegistry.hostingTreasury()).to.equal(hostingTreasury.address);
    });
  });
});