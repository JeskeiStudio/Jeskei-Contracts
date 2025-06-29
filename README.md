# Jeskei core contract set

   * deployer: 0x238D841A46f991C281539C2fb999127E3AfBddDd
   * JeskeiProxyFactory impl   → 0x3A9Be8484BD02458640c4226f87b3D3FBED6a60b
   * JeskeiProxyFactory proxy  → 0xd89B104E8Ba9DF8F9cf2fa896b33Cc3E2a5d1d48
   * UpgradeManager impl   → 0xdcC9f20F99075C16c1E606Ae9890dFf0bC40A71c
   * UpgradeManager proxy  → 0x65E89431Aa9b7f756B0599FDb8c78cD7Cbf1b1af
   * AssetRegistry proxy  → 0x727D3Fe8cF386a9b5E834D1b61a4B060a17df457
   * RevenueDistributor proxy  → 0x87ECD9eA5247A57C6D0F3FD142232430923ba3eF
   * PerformerAuthentication proxy  → 0x87ECD9eA5247A57C6D0F3FD142232430923ba3eF
   * AdvertisingEngine proxy  → 0x8984F1489591C07fb430A9984b264DaF6e101382
   * ContentAccess proxy  → 0x1fD7d46Ce51b8FA7bD8f2F81316Ea41A8fF8725C
   * DigitalStudioDAO proxy  → 0xee42229a98821d606B2404a41c1d08Ad0D05a7eF
   * CommunityGovernance impl → 0xa5e439638afe75031527E912C3e74d9Ce36C1E33

```shell
npx hardhat help
npx hardhat compile
npx hardhat deploy --network sepolia --tags Core
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```
