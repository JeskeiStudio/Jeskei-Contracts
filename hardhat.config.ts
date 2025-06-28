import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    // Local node for tests / scripts
    hardhat: {
      chainId: 31337,
      allowUnlimitedContractSize: true, // dev‑only – lets you unit‑test oversize contracts
    },

    // Sepolia test‑net
    sepolia: {
      url: process.env.SEPOLIA_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    },
  },
  namedAccounts: {
    // index → address mapping for deploy‑scripts
    deployer: {
      default: 0,
      sepolia: process.env.DEPLOYER_ADDRESS || "",
    },
    hostingTreasury: {
      default: 1,
      sepolia: process.env.HOSTING_TREASURY || "",
    },
    platformTreasury: {
      default: 2,
      sepolia: process.env.PLATFORM_TREASURY || "",
    },
    adTreasury: {
      default: 3,
      sepolia: process.env.AD_TREASURY || "",
    },
    crowdfundingTreasury: {
      default: 4,
      sepolia: process.env.CROWDFUNDING_TREASURY || "",
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },
};

export default config;