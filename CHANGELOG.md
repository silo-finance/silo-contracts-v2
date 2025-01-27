# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

## [1.1.0] - 2025-01-27
### Added
- solvBTC.BNN/solvBTC market sonic
- wS/scUSD market sonic
- Redeployment SiloDeployer
- silo-core: use underlying token decimals in collateral share token
- silo-oracles: invert flag

## [1.0.0] - 2025-01-20
### Added
- add rescue function to incentive controller

### Updated
- allow to restart incentive program after some time and ensure rewards are not calculated for a "gap"
- ensure claim rewards reset state after claiming

## [0.20.0] - 2025-01-10
### Updated
- Redeployment market for Sonic: `stS/S`
- Redeployment SiloRouter
- Redeployment GaugeHookReceiver with updated event and reduced contract size

## [0.19.0] - 2025-01-08
### Added
- Redeployment market for Sonic: `stS/S`
- Redeployment GaugeHookReceiver
- Extended LiquidationCall event
- silo vaults catch 63/64 gas attack

## [0.18.0] - 2025-01-07
### Added
- Sonic and Arbitrum deployments
- new market for Sonic: `stS/S`
- Silo Incentives controller
- Silo vaults incentives module and incentives claiming logic
- Renaming of 'MetaMorpho' to 'SiloVaults'
- Extended LiquidationCall event

## [0.17.3] - 2024-12-20
### Fixed
- allow LiquidationHelper to accept ETH

## [0.17.2] - 2024-12-16
### Added
- new markets for v0.17: `wstETH/WETH`, `gmETH/WETH`, `solvBTC/wBTC`, `ETHPlus/WETH`

## [0.17.1] - 2024-12-14
### Updated
- redeployment of silo-vault with `MIN_TIMELOCK` set to 1 minute for QA purposes

## [0.17.0] - 2024-12-14
### Updated
- redeployment of whole protocol

## [0.16.0] - 2024-12-12
### Added
- add support for custom oracle setup

## [0.15.1] - 2024-12-03
### Added
- add initial setup for IRM params: `ri` and `Tcrit`

### Fixed
- fix `maxBorrow` estimation

## [0.15.0] - 2024-12-02
### Added
- `PublicAllocator` contract for vaults
- add reentrancy for `withdrawFees`

### Fixed
- ensure transition deposit not fail when user insolvent

## [0.14.0] - 2024-11-25
### Added
- Vault functionality based on MetaMorpho
  - MetaMorpho was adjusted to work with ERC4626 standard
  - Concept of Idle market needs to be replaced with additional vault. By default, in Silo `IdleVault` is used. 

## [0.13.0] - 2024-11-19
### Added
- `LiquidationHelper` and `Tower`

## [0.12.1] - 2024-11-04
### Added
- LICENSE

### Changed
- modified license for some solidity files

### Fixed
- SiloLens redeployment

## [0.12.0] - 2024-11-01
### Added
- solvBTC/wBTC market Arbitrum
- gmETH/WETH market Arbitrum
- wstETH/WETH market Arbitrum
- ETH+/WETH market Arbitrum
- SiloRouter with preview methods instead of convertToAssets

## [0.11.0] - 2024-10-30
### Changed
- dao fee can be set based on range

## [0.10.1] - 2024-10-29
### Added
- optimism deployment

## [0.10.0] - 2024-10-28
### Changed
- make target LTV after liquidation configurable

## [0.9.1] - 2024-10-25
### Fixed
- SiloRouter with convertToAssets

## [0.9.0] - 2024-10-23
### Changed
- allow for forced transfer of debt
- use transient storage for reentrancy flag

### Fixed
- remove unchecked math from some places
- exclude protected assets from flashloan

### Removed
- remove `leverageSameAsset`
- remove self liquidation
- remove decimals from value calculations

## [0.8.0] - 2024-09-13

Design changes:

- The liquidation module was transformed into a hook receiver.
- Silo is now a share collateral token and implements share token functionality. So, now we have collateral share token (silo), protected share token (customized ERC-20), debt share token (customized ERC-20).
- Removed ‘bool sameAsset’ from the silo and introduced separate methods for work with the same asset.
- Removed ordered configs from the SiloConfig and introduced a collateral silo concept.
- Removed ‘leverage’ functionality from the Silo.borrow fn.
- Removed InterestRateModelV2.connect and added InterestRateModelV2.initialize. Now each silo has a different irm that is a minimal proxy and is cloned during the silo deployment like other components

## [0.7.0] - 2024-06-03
### Added
 - Refactoring of the hooks' actions and hooks inputs
 - Reentrancy bug fix in flashLoan fn
 - Rounding error bug fix in maxWithdraw fn
 - Overflow bug fix on maxWithdraw fn
 - ERC20Permit for share token
 - Added delegate call into the callOnBehalfOfSilo fn
 - Other minor fixes and improvements

## [0.6.2] - 2024-05-15
### Added
 - deployment with mocked CCIP and tokens for Arbitrum and Optimism

## [0.6.1] - 2024-05-14
### Fixed
- apply fixes for certora report

## [0.6.0] - 2024-05-06
### Added
- deposit to any silo without restrictions
- borrow same token
  - liquidation for same token can be done with sToken without reverting
  - case observed on full liquidation: when we empty out silo, there is dust left (no shares)

### Changed
- standard reentrancy guard was replaced by cross Silo reentrancy check

### Fixed
- fix issue with wrong configs in `isSolvent` after debt share transfer

## [0.5.0] - 2024-03-12
### Added
- SiloLens deploy

## [0.4.0] - 2024-02-22
### Added
- add returned code for `IHookReceiver.afterTokenTransfer`

## [0.3.3] - 2024-02-21
### Fixed
- underestimate `maxWithdraw`

## [0.3.2] - 2024-02-20
### Fixed
- fix rounding on `maxRedeem`
- fix rounding on `maxBorrow`

## [0.3.1] - 2024-02-19
### Fixed
- optimise `maxWithdraw`: do not run `getTotalCollateralAssetsWithInterest` twice

## [0.3.0] - 2024-02-15
### Added
- add `SiloLens` to reduced Silo size

### Changed
- change visibility of `total` mapping to public
- ensure total getters returns values with interest

### Removed
- remove `getProtectedAssets()`

## [0.2.0] - 2024-02-13
### Added
- Arbitrum and Optimism deployments

## [0.1.7] - 2024-02-12
### Fixed
- fix `maxBorrowShares` by using `-1`, same solution as we have for `maxBorrow`

## [0.1.6] - 2024-02-12
### Fixed
- fix max redeem: include interest for collateral assets

## [0.1.5] - 2024-02-08
### Fixed
- accrue interest on both silos for borrow

## [0.1.4] - 2024-02-08
### Changed
- improvements to `silo-core`, new test environments: certora, echidna

## [0.1.3] - 2024-02-07
### Fixed
- `SiloStdLib.flashFee` fn revert if `_amount` is `0`

## [0.1.2] - 2024-01-31
### Fixed
- ensure we can not deposit shares with `0` assets

## [0.1.1] - 2024-01-30
### Fixed
- ensure we can not borrow shares with `0` assets

## [0.1.0] - 2024-01-03
- code after first audit + develop changes

## [0.0.36] - 2023-12-27
### Fixed
- [issue-320](https://github.com/silo-finance/silo-contracts-v2/issues/320) TOB-SILO2-19: max* functions return
  incorrect values: underestimate `maxBorrow` more, to cover big amounts

## [0.0.35] - 2023-12-27
### Fixed
- [issue-320](https://github.com/silo-finance/silo-contracts-v2/issues/320) TOB-SILO2-19: max* functions return
  incorrect values: add liquidity limit when user has no debt

## [0.0.34] - 2023-12-22
### Fixed
- [TOB-SILO2-10](https://github.com/silo-finance/silo-contracts-v2/issues/300): Incorrect rounding direction in preview
  functions

## [0.0.33] - 2023-12-22
### Fixed
- [TOB-SILO2-13](https://github.com/silo-finance/silo-contracts-v2/issues/306): replaced leverageNonReentrant with nonReentrant,
  removed nonReentrant from the flashLoan fn

## [0.0.32] - 2023-12-22
### Fixed
- [issue-320](https://github.com/silo-finance/silo-contracts-v2/issues/320) TOB-SILO2-19: max* functions return 
  incorrect values

## [0.0.31] - 2023-12-18
### Fixed
- [issue-319](https://github.com/silo-finance/silo-contracts-v2/issues/319) TOB-SILO2-18: Minimum acceptable LTV is not
  enforced for full liquidation

## [0.0.30] - 2023-12-18
### Fixed
- [issue-286](https://github.com/silo-finance/silo-contracts-v2/issues/286) TOB-SILO2-3: Flash Loans cannot be performed 
  through the SiloRouter contract

## [0.0.29] - 2023-12-18
### Fixed
- [issue-322](https://github.com/silo-finance/silo-contracts-v2/issues/322) Repay reentrancy attack can drain all Silo assets

## [0.0.28] - 2023-12-18
### Fixed
- [issue-321](https://github.com/silo-finance/silo-contracts-v2/issues/321) Deposit reentrancy attack allows users to steal assets

## [0.0.27] - 2023-12-15
### Fixed
- [issue-255](https://github.com/silo-finance/silo-contracts-v2/issues/255): UniswapV3Oracle contract implementation 
  is left uninitialized

## [0.0.26] - 2023-12-15
### Fixed
- [TOB-SILO2-17](https://github.com/silo-finance/silo-contracts-v2/issues/318): Flashloan fee can round down to zero

## [0.0.25] - 2023-12-15
### Fixed
- [TOB-SILO2-16](https://github.com/silo-finance/silo-contracts-v2/issues/317): Minting zero collateral shares can 
  inflate share calculation

## [0.0.24] - 2023-12-15
### Fixed
- [TOB-SILO2-14](https://github.com/silo-finance/silo-contracts-v2/issues/314): Risk of daoAndDeployerFee overflow

## [0.0.23] - 2023-12-15
### Fixed
- [TOB-SILO2-12](https://github.com/silo-finance/silo-contracts-v2/issues/312): Risk of deprecated Chainlink oracles 
  locking user funds

## [0.0.22] - 2023-12-15
### Fixed
- [TOB-SILO2-10](https://github.com/silo-finance/silo-contracts-v2/issues/300): Incorrect rounding direction in preview 
  functions

## [0.0.21] - 2023-12-12
### Fixed
- [TOB-SILO2-13](https://github.com/silo-finance/silo-contracts-v2/issues/306): Users can borrow from and deposit to the 
  same silo vault to farm rewards

## [0.0.20] - 2023-12-11
### Fixed
EVM version changed to `paris`
- [Issue #285](https://github.com/silo-finance/silo-contracts-v2/issues/285)
- [Issue #215](https://github.com/silo-finance/silo-contracts-v2/issues/215)

## [0.0.19] - 2023-12-01
### Fixed
- TOB-SILO2-9: fix avoiding paying the flash loan fee

## [0.0.18] - 2023-12-01
### Fixed
- TOB-SILO2-7: fix fee distribution
- TOB-SILO2-8: fix fee transfer

## [0.0.17] - 2023-11-29
### Added
- TOB-SILO2-4: add 2-step ownership for `SiloFactory` and `GaugeHookReceiver`

## [0.0.16] - 2023-11-28
### Fixed
- TOB-SILO2-6: ensure no one can initialise GaugeHookReceiver and SiloFactory 

## [0.0.15] - 2023-11-28
### Fixed
- TOB-SILO2-1: ensure silo factory initialization can not be front-run

## [0.0.14] - 2023-11-28
### Fixed
- tob-silo2-5: fix deposit limit

## [0.0.13] - 2023-11-21
### Fixed
- fix `ASSET_DATA_OVERFLOW_LIMIT` in IRM model

## [0.0.11] - 2023-11-14
### Fixed
- [Issue #220](https://github.com/silo-finance/silo-contracts-v2/issues/220)

## [0.0.10] - 2023-11-14
### Fixed
- [Issue #223](https://github.com/silo-finance/silo-contracts-v2/issues/223)

## [0.0.9] - 2023-11-13
### Fixed
- [Issue #221](https://github.com/silo-finance/silo-contracts-v2/issues/221)

## [0.0.8] - 2023-11-13
### Fixed
- [Issue #219](https://github.com/silo-finance/silo-contracts-v2/issues/219)

## [0.0.7] - 2023-11-10
### Fixed
- [Issue #217](https://github.com/silo-finance/silo-contracts-v2/issues/217)

## [0.0.6] - 2023-11-10
### Fixed
- [Issue #216](https://github.com/silo-finance/silo-contracts-v2/issues/216)

## [0.0.5] - 2023-11-10
### Fixed
- [Issue #214](https://github.com/silo-finance/silo-contracts-v2/issues/214)

## [0.0.4] - 2023-11-10
### Fixed
- [Issue #213](https://github.com/silo-finance/silo-contracts-v2/issues/213)

## [0.0.3] - 2023-10-26
### Added
- silo-core for audit

## [0.0.2] - 2023-10-18
### Added
- silo-oracles for audit

## [0.0.1] - 2023-10-06
### Added
- ve-silo for audit
