// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {CrossReentrancy} from "./utils/CrossReentrancy.sol";
import {CrossEntrancy} from "./lib/CrossEntrancy.sol";
import {Hook} from "./lib/Hook.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";

// solhint-disable var-name-mixedcase


/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig, CrossReentrancy {
    using Hook for uint256;
    
    uint256 public immutable SILO_ID;

    uint256 private immutable _DAO_FEE;
    uint256 private immutable _DEPLOYER_FEE;
    address private immutable _LIQUIDATION_MODULE;
    address private immutable _HOOK_RECEIVER;

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

    // TODO do we need events for this? this is internal state only
    mapping (address borrower => DebtInfo debtInfo) internal _debtsInfo;
    
    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData0 silo configuration data for token0
    /// @param _configData1 silo configuration data for token1
    constructor(uint256 _siloId, ConfigData memory _configData0, ConfigData memory _configData1) CrossReentrancy() {
        SILO_ID = _siloId;

        _DAO_FEE = _configData0.daoFee;
        _DEPLOYER_FEE = _configData0.deployerFee;
        _LIQUIDATION_MODULE = _configData0.liquidationModule;
        _HOOK_RECEIVER = _configData0.hookReceiver;

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
    function crossNonReentrantBefore(uint256 _action) external virtual {
        if (_action.matchAction(CrossEntrancy.ENTERED_FROM_LEVERAGE)) {
            _onlySilo();
        } else {
            _onlySiloOrTokenOrLiquidation();
        }

        _crossNonReentrantBefore(_action);
    }

    /// @inheritdoc ISiloConfig
    function crossNonReentrantAfter() external virtual {
        _onlySiloOrTokenOrLiquidation();
        _crossNonReentrantAfter();
    }

    /// @inheritdoc ISiloConfig
    function onDebtTransfer(address _sender, address _recipient) external virtual {
        if (msg.sender != _DEBT_SHARE_TOKEN0 && msg.sender != _DEBT_SHARE_TOKEN1) revert OnlyDebtShareToken();

        DebtInfo storage recipientDebtInfo = _debtsInfo[_recipient];

        if (recipientDebtInfo.debtPresent) {
            // transferring debt not allowed, if _recipient has debt in other silo
            _forbidDebtInTwoSilos(recipientDebtInfo.debtInSilo0);
        } else {
            recipientDebtInfo.debtPresent = true;
            recipientDebtInfo.sameAsset = _debtsInfo[_sender].sameAsset;
            recipientDebtInfo.debtInSilo0 = msg.sender == _DEBT_SHARE_TOKEN0;
        }
    }

    /// @inheritdoc ISiloConfig
    function closeDebt(address _borrower) external virtual {
        if (msg.sender != _SILO0 && msg.sender != _SILO1 &&
            msg.sender != _DEBT_SHARE_TOKEN0 && msg.sender != _DEBT_SHARE_TOKEN1
        ) revert OnlySiloOrDebtShareToken();

        delete _debtsInfo[_borrower];
    }

    function accrueInterestAndGetConfig(address _silo, uint256 _action) external virtual returns (ConfigData memory) {
        _crossNonReentrantBefore(_action);
        _callAccrueInterest(_silo);

        if (_silo == _SILO0) {
            return _silo0ConfigData();
        } else if (_silo == _SILO1) {
            return _silo1ConfigData();
        } else {
            revert WrongSilo();
        }
    }

    function accrueInterestOnDeposit(
        address _silo,
        uint256 _action,
        ISilo.AssetType _assetType
    ) external virtual returns (address shareToken, address asset, address hookReceiver) {
        _crossNonReentrantBefore(_action);
        _callAccrueInterest(_silo);

        hookReceiver = _HOOK_RECEIVER;

        if (_silo == _SILO0) {
            asset = _TOKEN0;
            shareToken = _assetType == ISilo.AssetType.Collateral
                ? _COLLATERAL_SHARE_TOKEN0
                : _PROTECTED_COLLATERAL_SHARE_TOKEN0;
        } else if (_silo == _SILO1) {
            asset = _TOKEN1;
            shareToken = _assetType == ISilo.AssetType.Collateral
                ? _COLLATERAL_SHARE_TOKEN1
                : _PROTECTED_COLLATERAL_SHARE_TOKEN1;
        } else {
            revert WrongSilo();
        }
    }

    function accrueInterestAndGetConfigs(address _silo, address _borrower, uint256 _action)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        _crossNonReentrantBefore(_action);

        if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) {
            // share token transfer does not need configs
            return (collateralConfig, debtConfig, debtInfo);
        } else if (_action.matchAction(Hook.FLASH_LOAN)) {
            // flash loan does not need configs
            return (collateralConfig, debtConfig, debtInfo);
        } else if (_action.matchAction(Hook.BORROW)) {
            debtInfo = _openDebt(_borrower, _action);
        } else if (_action.matchAction(Hook.SWITCH_COLLATERAL)) {
            debtInfo = _changeCollateralType(_borrower, _action.matchAction(Hook.SAME_ASSET));
        } else {
            debtInfo = _debtsInfo[_borrower];
        }

        _callAccrueInterest(_silo);

        (collateralConfig, debtConfig) = _getOrderedConfigs(_silo, debtInfo, _action);
    }

    function crossReentrancyGuardEntered() external view virtual returns (bool) {
        return _crossReentrantStatus != CrossEntrancy.NOT_ENTERED;
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

    function getConfigs(address _silo, address _borrower, uint256 _action)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        debtInfo = _debtsInfo[_borrower];

        (collateralConfig, debtConfig) = _getOrderedConfigs(_silo, debtInfo, _action);
    }

    /// @inheritdoc ISiloConfig
    function getConfig(address _silo) external view virtual returns (ConfigData memory) {
        if (_silo == _SILO0) {
            return _silo0ConfigData();
        } else if (_silo == _SILO1) {
            return _silo1ConfigData();
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

    function _callAccrueInterest(address _silo) internal {
        ISilo(_silo).accrueInterestForConfig(
            _silo == _SILO0 ? _INTEREST_RATE_MODEL0 : _INTEREST_RATE_MODEL1,
            _DAO_FEE,
            _DEPLOYER_FEE
        );
    }

    /// @notice it will change collateral for existing debt, only silo can call it
    /// @return debtInfo details about `borrower` debt after the change
    function _changeCollateralType(address _borrower, bool _switchToSameAsset)
        internal
        virtual
        returns (DebtInfo memory debtInfo)
    {
        _onlySilo();

        debtInfo = _debtsInfo[_borrower];

        if (!debtInfo.debtPresent) revert NoDebt();
        if (debtInfo.sameAsset == _switchToSameAsset) revert CollateralTypeDidNotChanged();

        _debtsInfo[_borrower].sameAsset = _switchToSameAsset;
        debtInfo.sameAsset = _switchToSameAsset;
    }

    function _openDebt(address _borrower, uint256 _action) internal virtual returns (DebtInfo memory debtInfo) {
        _onlySilo();

        debtInfo = _debtsInfo[_borrower];

        if (!debtInfo.debtPresent) {
            debtInfo.debtPresent = true;
            debtInfo.sameAsset = _action.matchAction(Hook.SAME_ASSET);
            debtInfo.debtInSilo0 = msg.sender == _SILO0;

            _debtsInfo[_borrower] = debtInfo;
        }
    }

    function _getOrderedConfigs(address _silo, DebtInfo memory _debtInfo, uint256 _action)
        internal
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig)
    {
        bool callForSilo0 = _silo == _SILO0;
        if (!callForSilo0 && _silo != _SILO1) revert WrongSilo();

        uint256 order = ConfigLib.orderConfigs(_debtInfo, callForSilo0, _action);

        if (order == ConfigLib.SILO0_SILO0) {
            collateralConfig = _silo0ConfigData();
            debtConfig = collateralConfig;
        } else if (order == ConfigLib.SILO1_SILO0) {
            collateralConfig = _silo1ConfigData();
            debtConfig = _silo0ConfigData();
        } else if (order == ConfigLib.SILO0_SILO1) {
            collateralConfig = _silo0ConfigData();
            debtConfig = _silo1ConfigData();
        } else if (order == ConfigLib.SILO1_SILO1) {
            collateralConfig = _silo1ConfigData();
            debtConfig = collateralConfig;
        } else revert InvalidConfigOrder();
    }

    function _silo0ConfigData() internal view returns (ConfigData memory config) {
        config = ConfigData({
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
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE0
        });
    }

    // TODO make sure, this getters for configs does not increase gas
    function _silo1ConfigData() internal view returns (ConfigData memory config) {
        config = ConfigData({
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
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE1
        });
    }

    function _forbidDebtInTwoSilos(bool _debtInSilo0) internal view virtual {
        if (msg.sender == _DEBT_SHARE_TOKEN0 && _debtInSilo0) return;
        if (msg.sender == _DEBT_SHARE_TOKEN1 && !_debtInSilo0) return;

        revert DebtExistInOtherSilo();
    }

    function _onlySiloOrTokenOrLiquidation() internal view virtual {
        if (msg.sender != _SILO0 &&
            msg.sender != _SILO1 &&
            msg.sender != _LIQUIDATION_MODULE &&
            msg.sender != _COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _DEBT_SHARE_TOKEN0 &&
            msg.sender != _DEBT_SHARE_TOKEN1
        ) {
            revert OnlySiloOrLiquidationModule();
        }
    }

    function _onlySilo() internal view virtual {
        if (msg.sender != _SILO0 && msg.sender != _SILO1) revert OnlySilo();
    }
}
