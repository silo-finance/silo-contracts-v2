# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
