// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

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

    address private immutable _SOLVENCY_ORACLE0;
    address private immutable _MAX_LTV_ORACLE0;

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

    address private immutable _SOLVENCY_ORACLE1;
    address private immutable _MAX_LTV_ORACLE1;

    address private immutable _INTEREST_RATE_MODEL1;

    uint64 private immutable _MAX_LTV1;
    uint64 private immutable _LT1;
    uint64 private immutable _LIQUIDATION_FEE1;
    uint64 private immutable _FLASHLOAN_FEE1;

    bool private immutable _BORROWABLE1;

    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData0 silo configuration data for token0
    /// @param _configData1 silo configuration data for token1
    constructor(uint256 _siloId, ConfigData memory _configData0, ConfigData memory _configData1) {
        SILO_ID = _siloId;

        _DAO_FEE = _configData0.daoFeeInBp;
        _DEPLOYER_FEE = _configData0.deployerFeeInBp;

        // TOKEN #0

        _SILO0 = _configData0.silo;

        _TOKEN0 = _configData0.token;

        _PROTECTED_COLLATERAL_SHARE_TOKEN0 = _configData0.protectedShareToken;
        _COLLATERAL_SHARE_TOKEN0 = _configData0.collateralShareToken;
        _DEBT_SHARE_TOKEN0 = _configData0.debtShareToken;

        _SOLVENCY_ORACLE0 = _configData0.solvencyOracle;
        _MAX_LTV_ORACLE0 = _configData0.maxLtvOracle;

        _INTEREST_RATE_MODEL0 = _configData0.interestRateModel;

        _MAX_LTV0 = _configData0.maxLtv;
        _LT0 = _configData0.lt;
        _LIQUIDATION_FEE0 = _configData0.liquidationFee;
        _FLASHLOAN_FEE0 = _configData0.flashloanFee;

        _BORROWABLE0 = _configData0.borrowable;

        // TOKEN #1

        _SILO1 = _configData1.silo;

        _TOKEN1 = _configData1.token;

        _PROTECTED_COLLATERAL_SHARE_TOKEN1 = _configData1.protectedShareToken;
        _COLLATERAL_SHARE_TOKEN1 = _configData1.collateralShareToken;
        _DEBT_SHARE_TOKEN1 = _configData1.debtShareToken;

        _SOLVENCY_ORACLE1 = _configData1.solvencyOracle;
        _MAX_LTV_ORACLE1 = _configData1.maxLtvOracle;

        _INTEREST_RATE_MODEL1 = _configData1.interestRateModel;

        _MAX_LTV1 = _configData1.maxLtv;
        _LT1 = _configData1.lt;
        _LIQUIDATION_FEE1 = _configData1.liquidationFee;
        _FLASHLOAN_FEE1 = _configData1.flashloanFee;

        _BORROWABLE1 = _configData1.borrowable;
    }

    function getSilos() external view returns (address silo0, address silo1) {
        return (_SILO0, _SILO1);
    }

    function getShareTokens(address _silo)
        external
        view
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
    {
        if (_silo == _SILO0) {
            return (_PROTECTED_COLLATERAL_SHARE_TOKEN0, _COLLATERAL_SHARE_TOKEN0, _DEBT_SHARE_TOKEN0);
        } else if (_silo == _SILO1) {
            return (_PROTECTED_COLLATERAL_SHARE_TOKEN1, _COLLATERAL_SHARE_TOKEN1, _DEBT_SHARE_TOKEN1);
        } else {
            revert WrongSilo();
        }
    }

    function getAssetForSilo(address _silo) external view virtual returns (address asset) {
        if (_silo == _SILO0) {
            return _TOKEN0;
        } else if (_silo == _SILO1) {
            return _TOKEN1;
        } else {
            revert WrongSilo();
        }
    }

    function getConfigs(address _silo) external view virtual returns (ConfigData memory, ConfigData memory) {
        ConfigData memory configData0 = ConfigData({
            daoFeeInBp: _DAO_FEE,
            deployerFeeInBp: _DEPLOYER_FEE,
            silo: _SILO0,
            otherSilo: _SILO1,
            token: _TOKEN0,
            protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
            collateralShareToken: _COLLATERAL_SHARE_TOKEN0,
            debtShareToken: _DEBT_SHARE_TOKEN0,
            solvencyOracle: _SOLVENCY_ORACLE0,
            maxLtvOracle: _MAX_LTV_ORACLE0,
            interestRateModel: _INTEREST_RATE_MODEL0,
            maxLtv: _MAX_LTV0,
            lt: _LT0,
            liquidationFee: _LIQUIDATION_FEE0,
            flashloanFee: _FLASHLOAN_FEE0,
            borrowable: _BORROWABLE0
        });

        ConfigData memory configData1 = ConfigData({
            daoFeeInBp: _DAO_FEE,
            deployerFeeInBp: _DEPLOYER_FEE,
            silo: _SILO1,
            otherSilo: _SILO0,
            token: _TOKEN1,
            protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
            collateralShareToken: _COLLATERAL_SHARE_TOKEN1,
            debtShareToken: _DEBT_SHARE_TOKEN1,
            solvencyOracle: _SOLVENCY_ORACLE1,
            maxLtvOracle: _MAX_LTV_ORACLE1,
            interestRateModel: _INTEREST_RATE_MODEL1,
            maxLtv: _MAX_LTV1,
            lt: _LT1,
            liquidationFee: _LIQUIDATION_FEE1,
            flashloanFee: _FLASHLOAN_FEE1,
            borrowable: _BORROWABLE1
        });

        // Silo that is asking for configs will have its config at index 0
        if (_silo == _SILO0) {
            return (configData0, configData1);
        } else if (_silo == _SILO1) {
            return (configData1, configData0);
        } else {
            revert WrongSilo();
        }
    }

    function getConfig(address _silo) external view virtual returns (ConfigData memory) {
        if (_silo == _SILO0) {
            return ConfigData({
                daoFeeInBp: _DAO_FEE,
                deployerFeeInBp: _DEPLOYER_FEE,
                silo: _SILO0,
                otherSilo: _SILO1,
                token: _TOKEN0,
                protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
                collateralShareToken: _COLLATERAL_SHARE_TOKEN0,
                debtShareToken: _DEBT_SHARE_TOKEN0,
                solvencyOracle: _SOLVENCY_ORACLE0,
                maxLtvOracle: _MAX_LTV_ORACLE0,
                interestRateModel: _INTEREST_RATE_MODEL0,
                maxLtv: _MAX_LTV0,
                lt: _LT0,
                liquidationFee: _LIQUIDATION_FEE0,
                flashloanFee: _FLASHLOAN_FEE0,
                borrowable: _BORROWABLE0
            });
        } else if (_silo == _SILO1) {
            return ConfigData({
                daoFeeInBp: _DAO_FEE,
                deployerFeeInBp: _DEPLOYER_FEE,
                silo: _SILO1,
                otherSilo: _SILO0,
                token: _TOKEN1,
                protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
                collateralShareToken: _COLLATERAL_SHARE_TOKEN1,
                debtShareToken: _DEBT_SHARE_TOKEN1,
                solvencyOracle: _SOLVENCY_ORACLE1,
                maxLtvOracle: _MAX_LTV_ORACLE1,
                interestRateModel: _INTEREST_RATE_MODEL1,
                maxLtv: _MAX_LTV1,
                lt: _LT1,
                liquidationFee: _LIQUIDATION_FEE1,
                flashloanFee: _FLASHLOAN_FEE1,
                borrowable: _BORROWABLE1
            });
        } else {
            revert WrongSilo();
        }
    }

    function getFeesWithAsset(address _silo)
        external
        view
        virtual
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFeeInBp, address asset)
    {
        daoFee = _DAO_FEE;
        deployerFee = _DEPLOYER_FEE;

        if (_silo == _SILO0) {
            asset = _TOKEN0;
            flashloanFeeInBp = _FLASHLOAN_FEE0;
        } else if (_silo == _SILO1) {
            asset = _TOKEN1;
            flashloanFeeInBp = _FLASHLOAN_FEE1;
        } else {
            revert WrongSilo();
        }
    }
}
