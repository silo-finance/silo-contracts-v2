# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
