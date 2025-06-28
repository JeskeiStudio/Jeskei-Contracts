# Jeskei core contract set

   * deployer: 0x238D841A46f991C281539C2fb999127E3AfBddDd
   * JeskeiProxyFactory impl   → 0xEA90b92B4A3AA583AD27483b1247d80409752716
   * JeskeiProxyFactory proxy  → 0x89d3Bdfc7F9b3C6F07daa20366F6DC48a65daE07
   * UpgradeManager impl   → 0x131f79417eA023742C1a4Eb96968D73501Ea23ad
   * UpgradeManager proxy  → 0x1e3f3575027c21DAf2168ED57057bD5F66b3be0E
   * AssetRegistry proxy  → 0x028DddDA930452CD349872aB5d1C24eE183c06e9
   * RevenueDistributor proxy  → 0xA3CA068FcAeDd3Db12731FB83CC08dD9068A584E
   * PerformerAuthentication proxy  → 0xd1e6D033D6424797692A5bE675793d2b5D7D612d
   * AdvertisingEngine proxy  → 0x23A7E4aFE24F5E04c6F6d9EeB53aA9261077a3eF
   * ContentAccess proxy  → 0x664A869704Afa12772775DeB99A7814Faba81CC7
   * DigitalStudioDAO proxy  → 0xFBeD9E875552f16641c6f368D1D96B4846393243
   * CommunityGovernance impl → 0xdBb5eEA00a6d8a4B62e65dE8aC355679C02515cA

```shell
npx hardhat help
npx hardhat compile
npx hardhat deploy --network sepolia --tags Core
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```
