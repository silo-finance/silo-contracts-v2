// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {IShareDebtToken} from "./interfaces/IShareDebtToken.sol";
import {TypesLib} from "./lib/TypesLib.sol";

// solhint-disable var-name-mixedcase

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig {
    uint256 public immutable SILO_ID;

    uint256 private immutable _DAO_FEE;
    uint256 private immutable _DEPLOYER_FEE;
    address private immutable _LIQUIDATION_MODULE;

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

    uint256 private immutable _MAX_LTV0;
    uint256 private immutable _LT0;
    uint256 private immutable _LIQUIDATION_FEE0;
    uint256 private immutable _FLASHLOAN_FEE0;

    bool private immutable _CALL_BEFORE_QUOTE0;

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

    uint256 private immutable _MAX_LTV1;
    uint256 private immutable _LT1;
    uint256 private immutable _LIQUIDATION_FEE1;
    uint256 private immutable _FLASHLOAN_FEE1;

    bool private immutable _CALL_BEFORE_QUOTE1;

    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData0 silo configuration data for token0
    /// @param _configData1 silo configuration data for token1
    constructor(uint256 _siloId, ConfigData memory _configData0, ConfigData memory _configData1) {
        SILO_ID = _siloId;

        _DAO_FEE = _configData0.daoFee;
        _DEPLOYER_FEE = _configData0.deployerFee;

        _LIQUIDATION_MODULE = _configData0.liquidationModule;

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

        _CALL_BEFORE_QUOTE0 = _configData0.callBeforeQuote;

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

        _CALL_BEFORE_QUOTE1 = _configData1.callBeforeQuote;
    }

    /// @inheritdoc ISiloConfig
    function getSilos() external view returns (address silo0, address silo1) {
        return (_SILO0, _SILO1);
    }

    /// @inheritdoc ISiloConfig
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

    /// @inheritdoc ISiloConfig
    function getAssetForSilo(address _silo) external view virtual returns (address asset) {
        if (_silo == _SILO0) {
            return _TOKEN0;
        } else if (_silo == _SILO1) {
            return _TOKEN1;
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getConfigs(address _silo, address _user, uint256 _configFor)
        external
        view
        virtual
        returns (ConfigData memory collateral, ConfigData memory debt, uint256 positionType)
    {
        ConfigData memory configData0 = ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
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
            liquidationModule: _LIQUIDATION_MODULE,
            callBeforeQuote: _CALL_BEFORE_QUOTE0
        });

        ConfigData memory configData1 = ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
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
            liquidationModule: _LIQUIDATION_MODULE,
            callBeforeQuote: _CALL_BEFORE_QUOTE1
        });

        bool isSilo0 = _silo == _SILO0;
        if (!isSilo0 && _silo != _SILO1) revert WrongSilo();

        bool configForBorrow = _configFor == TypesLib.CONFIG_FOR_BORROW;

        positionType = IShareDebtToken(isSilo0 ? _DEBT_SHARE_TOKEN0 : _DEBT_SHARE_TOKEN1).positionType(_user);

        if (positionType == TypesLib.POSITION_TYPE_ONE_TOKEN) { // this _silo is debt
            // this _silo is debt
            return isSilo0
                ? (configData0, configData0, TypesLib.POSITION_TYPE_ONE_TOKEN)
                : (configData1, configData1, TypesLib.POSITION_TYPE_ONE_TOKEN);
        }

        if (positionType == TypesLib.POSITION_TYPE_TWO_TOKENS) { // this _silo is debt
            if (configForBorrow) {
                return isSilo0
                    ? (configData1, configData0, TypesLib.POSITION_TYPE_TWO_TOKENS)
                    : (configData0, configData1, TypesLib.POSITION_TYPE_TWO_TOKENS);
            } else { // withdraw
                return isSilo0
                    ? (configData0, debt /* empty config */, TypesLib.POSITION_TYPE_DEPOSIT)
                    : (configData1, debt /* empty config */, TypesLib.POSITION_TYPE_DEPOSIT);
            }
        }

        // this _silo has no debt, checking the other one

        positionType = IShareDebtToken(isSilo0 ? _DEBT_SHARE_TOKEN1 : _DEBT_SHARE_TOKEN0).positionType(_user);

        if (positionType == TypesLib.POSITION_TYPE_ONE_TOKEN) { // this _silo is with collateral
            return configForBorrow
                ? (collateral, debt, TypesLib.POSITION_TYPE_DEPOSIT) // can not borrow
                : (isSilo0 ? configData0 : configData1, debt, TypesLib.POSITION_TYPE_DEPOSIT);
        }

        if (positionType == TypesLib.POSITION_TYPE_TWO_TOKENS) { // this _silo is with collateral
            if (configForBorrow) {
                return (collateral, debt, TypesLib.POSITION_TYPE_DEPOSIT); // can not borrow
            } else {
                return isSilo0
                    ? (configData0, configData1, TypesLib.POSITION_TYPE_TWO_TOKENS)
                    : (configData1, configData0, TypesLib.POSITION_TYPE_TWO_TOKENS);
            }
        }

        // there is no debt if we got to this point

        // Silo that is asking for configs will have its config at index 0
        return isSilo0 ? (configData0, configData1) : (configData1, configData0);
    }

    /// @inheritdoc ISiloConfig
    function getConfig(address _silo) external view virtual returns (ConfigData memory) {
        if (_silo == _SILO0) {
            return ConfigData({
                daoFee: _DAO_FEE,
                deployerFee: _DEPLOYER_FEE,
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
                liquidationModule: _LIQUIDATION_MODULE,
                callBeforeQuote: _CALL_BEFORE_QUOTE0
            });
        } else if (_silo == _SILO1) {
            return ConfigData({
                daoFee: _DAO_FEE,
                deployerFee: _DEPLOYER_FEE,
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
                liquidationModule: _LIQUIDATION_MODULE,
                callBeforeQuote: _CALL_BEFORE_QUOTE1
            });
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getFeesWithAsset(address _silo)
        external
        view
        virtual
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset)
    {
        daoFee = _DAO_FEE;
        deployerFee = _DEPLOYER_FEE;

        if (_silo == _SILO0) {
            asset = _TOKEN0;
            flashloanFee = _FLASHLOAN_FEE0;
        } else if (_silo == _SILO1) {
            asset = _TOKEN1;
            flashloanFee = _FLASHLOAN_FEE1;
        } else {
            revert WrongSilo();
        }
    }
}
