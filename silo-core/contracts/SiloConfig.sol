// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

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

    mapping (address borrower => DebtInfo debtInfo) internal _debtsInfo;
    
    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData0 silo configuration data for token0
    /// @param _configData1 silo configuration data for token1
    constructor(uint256 _siloId, ConfigData memory _configData0, ConfigData memory _configData1) CrossReentrancy() {
        SILO_ID = _siloId;

        // To make further computations in the Silo secure require DAO and deployer fees to be less than 100%
        if (_configData0.daoFee + _configData0.deployerFee >= 1e18) revert FeeTooHigh();

        _DAO_FEE = _configData0.daoFee;
        _DEPLOYER_FEE = _configData0.deployerFee;
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
    
    modifier beforeGetConfigFor(uint256 _action) {
        _crossNonReentrantBefore(_action);
        _callAccrueInterest();
        
        _;
    }

    /// @inheritdoc ISiloConfig
    function crossNonReentrantBefore(uint256 _action) external virtual { 
        if (_action.matchAction(CrossEntrancy.ENTERED_FROM_LEVERAGE)) {
            _onlySilo();
        } else {
            _onlySiloOrTokenOrHookReceiver();
        }

        _crossNonReentrantBefore(_action);
    }

    /// @inheritdoc ISiloConfig
    function crossNonReentrantAfter() external virtual {
        _onlySiloOrTokenOrHookReceiver();
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

    /*
     - we might simplify code if we replace `_silo` with `msg.sender` for non view methods that pull config,
     - we can also remove accrue from name since we will always accrue from here
    */
    function accrueInterestAndGetConfig(uint256 _action) beforeGetConfigFor(_action) external virtual returns (ConfigData memory) {
        if (msg.sender == _SILO0) {
            ISilo(_SILO1).accrueInterest();
            return _silo0ConfigData();
        } else if (msg.sender == _SILO1) {
            ISilo(_SILO0).accrueInterest();
            return _silo1ConfigData();
        } else {
            revert WrongSilo();
        }
    }

    function accrueInterestAndGetConfigOptimised(
        uint256 _action,
        ISilo.CollateralType _collateralType
    ) beforeGetConfigFor(_action) external virtual returns (address shareToken, address asset) {
        if (msg.sender == _SILO0) {
            asset = _TOKEN0;

            if (_action.matchAction(Hook.REPAY)) {
                shareToken = _DEBT_SHARE_TOKEN0;
            } else if (_action.matchAction(Hook.DEPOSIT)) {
                shareToken = _collateralType == ISilo.CollateralType.Collateral
                    ? _COLLATERAL_SHARE_TOKEN0
                    : _PROTECTED_COLLATERAL_SHARE_TOKEN0;
            } else revert("unexpected");
        } else if (msg.sender == _SILO1) {
            asset = _TOKEN1;

            if (_action.matchAction(Hook.REPAY)) {
                shareToken = _DEBT_SHARE_TOKEN1;
            } else if (_action.matchAction(Hook.DEPOSIT)) {
                shareToken = _collateralType == ISilo.CollateralType.Collateral
                    ? _COLLATERAL_SHARE_TOKEN1
                    : _PROTECTED_COLLATERAL_SHARE_TOKEN1;
            } else revert("unexpected");
        } else {
            revert WrongSilo();
        }
    }

    // I would prefer wrap them under one method and called based on if(_action) ... to save config size
    // but it works as separate methods as well
    function getConfigsForWithdraw(address _borrower, uint256 _action)
        beforeGetConfigFor(_action)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        bool callForSilo0 = msg.sender == _SILO0;
        if (!callForSilo0 && msg.sender != _SILO1) revert WrongSilo();

        debtInfo = _debtsInfo[_borrower];
        uint256 order = ConfigLib.orderConfigsForWithdraw(debtInfo, callForSilo0);
        (collateralConfig, debtConfig) = _getOrderedConfigs(order);
    }

    function getConfigsForBorrow(address _borrower, uint256 _action)
        beforeGetConfigFor(_action)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        debtInfo = _openDebt(_borrower, _action);
        (collateralConfig, debtConfig) = _getConfigsForBorrow(msg.sender, debtInfo, _action);
    }

    function _getConfigsForBorrow(address _silo, DebtInfo memory _debtInfo, uint256 _action)
        internal
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig)
    {
        bool callForSilo0 = _silo == _SILO0;
        if (!callForSilo0 && _silo != _SILO1) revert WrongSilo();

        uint256 order = ConfigLib.orderConfigsForBorrow(_debtInfo, callForSilo0, _action);
        return _getOrderedConfigs(order);
    }

    function getConfigsForSwitchCollateral(address _borrower, uint256 _action)
        beforeGetConfigFor(_action)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        bool callForSilo0 = msg.sender == _SILO0;
        if (!callForSilo0 && msg.sender != _SILO1) revert WrongSilo();

        debtInfo = _changeCollateralType(_borrower, _action.matchAction(Hook.SAME_ASSET));
        uint256 order = ConfigLib.orderConfigs(debtInfo, callForSilo0);
        (collateralConfig, debtConfig) = _getOrderedConfigs(order);
    }

    function crossReentrantStatus() external view virtual returns (bool entered, uint256 status) {
        status = _crossReentrantStatus;
        entered = status != CrossEntrancy.NOT_ENTERED;
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

        if (_action.matchAction(Hook.BORROW)) _getConfigsForBorrow(_silo, debtInfo, _action);
        // else... call proper method, for non view method I created external methods but I think there is no point.
        // wrapper with if-else is better and will save config size
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

    /*
     config is needed always, for any action so let's use this fact for:
     - x-reentrancy as is, this is best way to turn it ON always since we can not use modifier (because of hooks)
     - accrue (probably remove it from silo and actions completely) and we will be sure we call it always for both silos
    */
    function _callAccrueInterest() internal {
        // I would call here accrue on other silo and if this will simplify code, on this silo as well
        // so we have all in one place
        // downside: we will call accrue on both silos even for deposit nad repay
        ISilo(_SILO0).accrueInterestForConfig(
            _INTEREST_RATE_MODEL0,
            _DAO_FEE,
            _DEPLOYER_FEE
        );

        ISilo(_SILO1).accrueInterestForConfig(
            _INTEREST_RATE_MODEL1,
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

    // we have to manage debt in config anyway, so simplest solution is expose all method and make them
    // only share token? TODO
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
    
    function _getOrderedConfigs(uint256 _order)
        internal
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig)
    {
        if (_order == ConfigLib.COLLATERAL0_DEBT0) {
            collateralConfig = _silo0ConfigData();
            debtConfig = collateralConfig;
        } else if (_order == ConfigLib.COLLATERAL1_DEBT0) {
            collateralConfig = _silo1ConfigData();
            debtConfig = _silo0ConfigData();
        } else if (_order == ConfigLib.COLLATERAL0_DEBT1) {
            collateralConfig = _silo0ConfigData();
            debtConfig = _silo1ConfigData();
        } else if (_order == ConfigLib.COLLATERAL1_DEBT1) {
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
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE0
        });
    }

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
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE1
        });
    }

    function _forbidDebtInTwoSilos(bool _debtInSilo0) internal view virtual {
        if (msg.sender == _DEBT_SHARE_TOKEN0 && _debtInSilo0) return;
        if (msg.sender == _DEBT_SHARE_TOKEN1 && !_debtInSilo0) return;

        revert DebtExistInOtherSilo();
    }

    function _onlySiloOrTokenOrHookReceiver() internal view virtual {
        if (msg.sender != _SILO0 &&
            msg.sender != _SILO1 &&
            msg.sender != _HOOK_RECEIVER &&
            msg.sender != _COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _DEBT_SHARE_TOKEN0 &&
            msg.sender != _DEBT_SHARE_TOKEN1
        ) {
            revert OnlySiloOrHookReceiver();
        }
    }

    function _onlySilo() internal view virtual {
        if (msg.sender != _SILO0 && msg.sender != _SILO1) revert OnlySilo();
    }
}
