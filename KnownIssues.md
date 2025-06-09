## Known issues:

### Decimals

`decimals()` function in `SiloVault` and `Silo` does not add decimal offset to decimals of underlaying asset. Both contracts use decimal offset but it is not reflected in `decimals()` function return value.

SiloVault:
  decimals(): same as underlying asset
  offset: 6
  minted shares per 1 wei of asset deposited: 1000000

Silo:
  decimals(): same as underlying asset
  offset: 3
  minted shares per 1 wei of asset deposited: 1000

ProtectedShareToken:
  decimals(): same as underlying asset
  offset: 3
  minted shares per 1 wei of asset deposited: 1000

DebtShareToken:
  decimals(): same as underlying asset
  offset: 0
  shares per 1 wei of asset borrowed: 1

Learn more about the [decimal offset here](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/a7d38c7a3321e3832ca84f7ba1125dff9a91361e/contracts/token/ERC20/extensions/ERC4626.sol#L31)

The share-to-asset ratio may change over time due to interest accrual. Assets grow with interest but the number 
of shares remains constant, the ratio will adjust dynamically.

To determine the current conversion rate, use the vault’s `convertToShares(1 asset)` method.

For `SiloVault` and `Silo` `decimals()` fn return underlying asset decimals (USDC - 6, WETH - 18).

### `getProgramName()`

Silo incentives controller with version < 3.6.0 has issue with `getProgramName` fn. It fails to convert the immediate 
distribution program name into a proper string representation.
Silos incentives controller with this issue: Sonic 1 - 101, Arbitrum 100 - 111, Optimism - 100, Ink - 100 - 101.
