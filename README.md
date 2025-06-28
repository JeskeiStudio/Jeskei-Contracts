# Jeskei core contract set

   * deployer: 0x238D841A46f991C281539C2fb999127E3AfBddDd
   * JeskeiProxyFactory impl   → 0x21f014ec8cB70a1De62861A404Bf78f05eC93F76
   * JeskeiProxyFactory proxy  → 0x3636ad3554C0abb474AD76E59a50aaeFb53c207A
   * UpgradeManager impl   → 0xb42c5BF910EAfF050B8b2d276B0b550E3EF7Ab67
   * UpgradeManager proxy  → 0xE7e57507A55F9E9DFfA4D15914B1c078867bc90F
   * AssetRegistry proxy  → 0x2c1400Db47a9642DDf2e6E095f92C7Ac74e70cEd
   * RevenueDistributor proxy  → 0x2B20ca0A2F921a737482310BCF7322B903844753
   * PerformerAuthentication proxy  → 0x59fCc0c8745BC8de69F20133C7ad16dF8105F18c

```shell
npx hardhat help
npx hardhat compile
npx hardhat deploy --network sepolia --tags Core
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```
