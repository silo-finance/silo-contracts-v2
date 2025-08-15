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

### Debt share tokens approval for the leverage smart contract

The leverage contract requires approval of share debt tokens so it can borrow on behalf of the user. Recent versions of the debt share token used `approve` fn for that, but it was changed in PR#1098 (Release 3.0.0), and after that change, we need to use `setReceiveApproval` fn.

Silos with id < 100 on Sonic use `approve`. All other versions use `setReceiveApproval` fn.

### Liquidation collateral overestimation

The `PartialLiquidationLib` uses a fixed `_UNDERESTIMATION` constant of 2 wei to account for rounding errors during liquidation conversions (assets → shares → assets). This underestimation becomes insufficient when the asset-to-share ratio is high.

During liquidation, the protocol performs two conversions that both round down:
1. Converting collateral assets to shares (rounds down)
2. Converting shares back to assets for withdrawal (rounds down)

With high asset/share ratios, the cumulative rounding error can exceed 2 wei. This causes `maxLiquidation()` to overestimate the available collateral, potentially leading to failed liquidation transactions when the actual withdrawable amount is less than calculated.
