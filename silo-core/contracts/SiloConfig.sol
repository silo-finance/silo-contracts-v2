// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

// solhint-disable var-name-mixedcase

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig {
    uint256 public immutable SILO_ID;

    uint256 private immutable _DAO_FEE;
    uint256 private immutable _DEPLOYER_FEE;

    // TOKEN #0

    address private immutable _SILO0;

    address private immutable _TOKEN0;

    /// @dev Token that represents a share in total protected deposits of Silo
    address private immutable _PROTECTED_COLLATERAL_SHARE_TOKEN0;
    /// @dev Token that represents a share in total deposits of Silo
    address private immutable _COLLATERAL_SHARE_TOKEN0;
    /// @dev Token that represents a share in total debt of Silo
    address private immutable _DEBT_SHARE_TOKEN0;

    address private immutable _LTV_ORACLE0;
    address private immutable _LT_ORACLE0;

    address private immutable _INTEREST_RATE_MODEL0;

    uint64 private immutable _MAX_LTV0;
    uint64 private immutable _LT0;
    uint64 private immutable _LIQUIDATION_FEE0;
    uint64 private immutable _FLASHLOAN_FEE0;

    bool private immutable _BORROWABLE0;

    // TOKEN #1

    address private immutable _SILO1;

    address private immutable _TOKEN1;

    /// @dev Token that represents a share in total protected deposits of Silo
    address private immutable _PROTECTED_COLLATERAL_SHARE_TOKEN1;
    /// @dev Token that represents a share in total deposits of Silo
    address private immutable _COLLATERAL_SHARE_TOKEN1;
    /// @dev Token that represents a share in total debt of Silo
    address private immutable _DEBT_SHARE_TOKEN1;

    address private immutable _LTV_ORACLE1;
    address private immutable _LT_ORACLE1;

    address private immutable _INTEREST_RATE_MODEL1;

    uint64 private immutable _MAX_LTV1;
    uint64 private immutable _LT1;
    uint64 private immutable _LIQUIDATION_FEE1;
    uint64 private immutable _FLASHLOAN_FEE1;

    bool private immutable _BORROWABLE1;

    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData silo configuration data
    constructor(uint256 _siloId, ConfigData memory _configData) {
        SILO_ID = _siloId;

        _DAO_FEE = _configData.daoFee;
        _DEPLOYER_FEE = _configData.deployerFee;

        // TOKEN #0

        _SILO0 = _configData.silo0;

        _TOKEN0 = _configData.token0;

        _PROTECTED_COLLATERAL_SHARE_TOKEN0 = _configData.protectedShareToken0;
        _COLLATERAL_SHARE_TOKEN0 = _configData.collateralShareToken0;
        _DEBT_SHARE_TOKEN0 = _configData.debtShareToken0;

        _LTV_ORACLE0 = _configData.ltvOracle0;
        _LT_ORACLE0 = _configData.ltOracle0;

        _INTEREST_RATE_MODEL0 = _configData.interestRateModel0;

        _MAX_LTV0 = _configData.maxLtv0;
        _LT0 = _configData.lt0;
        _LIQUIDATION_FEE0 = _configData.liquidationFee0;
        _FLASHLOAN_FEE0 = _configData.flashloanFee0;

        _BORROWABLE0 = _configData.borrowable0;

        // TOKEN #1

        _SILO1 = _configData.silo1;

        _TOKEN1 = _configData.token1;

        _PROTECTED_COLLATERAL_SHARE_TOKEN1 = _configData.protectedShareToken1;
        _COLLATERAL_SHARE_TOKEN1 = _configData.collateralShareToken1;
        _DEBT_SHARE_TOKEN1 = _configData.debtShareToken1;

        _LTV_ORACLE1 = _configData.ltvOracle1;
        _LT_ORACLE1 = _configData.ltOracle1;

        _INTEREST_RATE_MODEL1 = _configData.interestRateModel1;

        _MAX_LTV1 = _configData.maxLtv1;
        _LT1 = _configData.lt1;
        _LIQUIDATION_FEE1 = _configData.liquidationFee1;
        _FLASHLOAN_FEE1 = _configData.flashloanFee1;

        _BORROWABLE1 = _configData.borrowable1;
    }

    function getAssetForSilo(address _silo) public view returns (address asset) {
        if (_silo == _SILO0) {
            return _TOKEN0;
        } else if (_silo == _SILO1) {
            return _TOKEN1;
        } else {
            revert WrongSilo();
        }
    }

    function getConfig() public view returns (ConfigData memory) {
        return ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
            silo0: _SILO0,
            token0: _TOKEN0,
            protectedShareToken0: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
            collateralShareToken0: _COLLATERAL_SHARE_TOKEN0,
            debtShareToken0: _DEBT_SHARE_TOKEN0,
            ltvOracle0: _LTV_ORACLE0,
            ltOracle0: _LT_ORACLE0,
            interestRateModel0: _INTEREST_RATE_MODEL0,
            maxLtv0: _MAX_LTV0,
            lt0: _LT0,
            liquidationFee0: _LIQUIDATION_FEE0,
            flashloanFee0: _FLASHLOAN_FEE0,
            borrowable0: _BORROWABLE0,
            silo1: _SILO1,
            token1: _TOKEN1,
            protectedShareToken1: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
            collateralShareToken1: _COLLATERAL_SHARE_TOKEN1,
            debtShareToken1: _DEBT_SHARE_TOKEN1,
            ltvOracle1: _LTV_ORACLE1,
            ltOracle1: _LT_ORACLE1,
            interestRateModel1: _INTEREST_RATE_MODEL1,
            maxLtv1: _MAX_LTV1,
            lt1: _LT1,
            liquidationFee1: _LIQUIDATION_FEE1,
            flashloanFee1: _FLASHLOAN_FEE1,
            borrowable1: _BORROWABLE1
        });
    }

    /// @dev returns only part of the config needed for deposit and repey to save gas
    ///      Getting full config (ConfigData) costs ~3k gas. Small config (SmallConfigData) costs ~1.4k gas.
    ///      SmallConfigData is always casted to ConfigData so it's tempting to do casting here but full config with
    ///      empty data costs ~2.4k gas so it makes sense to cast in memory outside of this contract.
    function getSmallConfigWithAsset(address _silo)
        public
        view
        returns (SmallConfigData memory configData, address asset)
    {
        configData.daoFee = _DAO_FEE;
        configData.deployerFee = _DEPLOYER_FEE;
        configData.token0 = _TOKEN0;
        configData.protectedShareToken0 = _PROTECTED_COLLATERAL_SHARE_TOKEN0;
        configData.collateralShareToken0 = _COLLATERAL_SHARE_TOKEN0;
        configData.debtShareToken0 = _DEBT_SHARE_TOKEN0;
        configData.interestRateModel0 = _INTEREST_RATE_MODEL0;
        configData.token1 = _TOKEN1;
        configData.protectedShareToken1 = _PROTECTED_COLLATERAL_SHARE_TOKEN1;
        configData.collateralShareToken1 = _COLLATERAL_SHARE_TOKEN1;
        configData.debtShareToken1 = _DEBT_SHARE_TOKEN1;
        configData.interestRateModel1 = _INTEREST_RATE_MODEL1;

        asset = getAssetForSilo(_silo);
    }

    function getConfigWithAsset(address _silo) public view returns (ConfigData memory configData, address asset) {
        configData = getConfig();
        asset = getAssetForSilo(_silo);
    }

    function getFlashloanFeeWithAsset(address _silo) public view returns (uint256 flashloanFee, address asset) {
        if (_silo == _SILO0) {
            flashloanFee = _FLASHLOAN_FEE0;
            asset = _TOKEN0;
        } else if (_silo == _SILO1) {
            flashloanFee = _FLASHLOAN_FEE1;
            asset = _TOKEN1;
        } else {
            revert WrongSilo();
        }
    }
}
