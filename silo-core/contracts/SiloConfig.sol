// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

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

    mapping (address borrower => address collateralSilo) internal borrowerCollateralSilo;
    mapping (address borrower => DebtInfo debtInfo) internal _debtsInfo;

    error DebtInTwoSilos();
    
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

    /// @inheritdoc ISiloConfig
    function crossNonReentrantBefore() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        _crossNonReentrantBefore();
    }

    /// @inheritdoc ISiloConfig
    function crossNonReentrantAfter() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        _crossNonReentrantAfter();
    }

    /// @inheritdoc ISiloConfig
    function setCollateralSilo(address _borrower, bool _sameAsset) external {
        _onlySilo();

        _setCollateralSilo(msg.sender, _borrower, _sameAsset);
    }

    function _setCollateralSilo(address _debtSilo, address _borrower, bool _sameAsset) internal {
        address otherSilo = _debtSilo == _SILO0 ? _SILO1 : _SILO0;
        borrowerCollateralSilo[_borrower] = _sameAsset ? _debtSilo : otherSilo;

        if (_sameAsset) {
            // the same as msg.sender
            collateralSilo =  _silo == _SILO0 ? _SILO0 : _SILO1;
        } else {
            // the other silo
            collateralSilo =  _silo == _SILO0 ? _SILO1 : _SILO0;
        }

        borrowerCollateralSilo[_borrower] = collateralSilo;
    }

    /// @inheritdoc ISiloConfig
    function onDebtTransfer(address _sender, address _recipient) external virtual {
        _onlyDebtShareToken();

        if (borrowerCollateralSilo[_recipient] == address(0)) {
            borrowerCollateralSilo[_recipient] = borrowerCollateralSilo[_sender];
        }
    }

    function forbidDebtInTwoSilos(address _borrower) external view virtual {
        _onlyDebtShareToken();

        address otherSiloDebtToken = msg.sender == _DEBT_SHARE_TOKEN0 ? _DEBT_SHARE_TOKEN1 : _DEBT_SHARE_TOKEN0;

        uint256 debtBalanceInOtherSilo = IERC20(otherSiloDebtToken).balanceOf(_borrower);

        if (debtBalanceInOtherSilo != 0) revert DebtExistInOtherSilo();
    }

    function accrueInterestAndGetConfig(address _silo) external virtual returns (ConfigData memory) {
        _crossNonReentrantBefore();
        _callAccrueInterest(_silo);

        if (_silo == _SILO0) {
            return _silo0ConfigData();
        } else if (_silo == _SILO1) {
            return _silo1ConfigData();
        } else {
            revert WrongSilo();
        }
    }

    function accrueInterestAndGetConfigOptimised(
        uint256 _action,
        ISilo.CollateralType _collateralType
    ) external virtual returns (address shareToken, address asset) {
        _crossNonReentrantBefore();
        _callAccrueInterest(msg.sender);

        if (msg.sender == _SILO0) {
            asset = _TOKEN0;

            if (_action.matchAction(Hook.REPAY)) {
                shareToken = _DEBT_SHARE_TOKEN0;
            } else {
                shareToken = _collateralType == ISilo.CollateralType.Collateral
                    ? _COLLATERAL_SHARE_TOKEN0
                    : _PROTECTED_COLLATERAL_SHARE_TOKEN0;
            }
        } else if (msg.sender == _SILO1) {
            asset = _TOKEN1;

            if (_action.matchAction(Hook.REPAY)) {
                shareToken = _DEBT_SHARE_TOKEN1;
            } else {
                shareToken = _collateralType == ISilo.CollateralType.Collateral
                    ? _COLLATERAL_SHARE_TOKEN1
                    : _PROTECTED_COLLATERAL_SHARE_TOKEN1;
            }
        } else {
            revert WrongSilo();
        }
    }

    function accrueInterestAndGetConfigs(address _silo, address _borrower, uint256 _action)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        _crossNonReentrantBefore();

        if (_action.matchAction(Hook.BORROW)) {
            _onlySilo();
            // debtInfo = _openDebt(_borrower, _action);
            _setCollateralSilo(msg.sender, _borrower, _action.matchAction(Hook.SAME_ASSET));
        } else if (_action.matchAction(Hook.SWITCH_COLLATERAL)) {
            _onlySilo();
            // _changeCollateralType(_borrower, _action.matchAction(Hook.SAME_ASSET));

            debtInfo = _getDebtInfo(_silo, _borrower);

            bool switchToSameAsset = _action.matchAction(Hook.SAME_ASSET);

            if (!debtInfo.debtPresent) revert NoDebt();
            if (debtInfo.sameAsset == switchToSameAsset) revert CollateralTypeDidNotChanged();

            _setCollateralSilo(msg.sender, _borrower, switchToSameAsset);
        } else {
            // TODO looks like anyone can raise flag if there is no action taken?
            // debtInfo = _debtsInfo[_borrower];
        }

        debtInfo = _getDebtInfo(_silo, _borrower);

        _callAccrueInterest(_silo);

        (collateralConfig, debtConfig) = _getOrderedConfigs(_silo, debtInfo, _action);
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
        debtInfo = _getDebtInfo(_silo, _borrower);
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

    function _getDebtInfo(address _silo, address _borrower)
        internal
        view
        virtual
        returns (DebtInfo memory debtInfo)
    {
        address debtSilo = getDebtSilo(_borrower);

        if (debtSilo == address(0)) return debtInfo; // no debt

        address collateralSilo = borrowerCollateralSilo[_borrower];

        debtInfo.debtPresent = true;
        debtInfo.sameAsset = collateralSilo == debtSilo;
        debtInfo.debtInSilo0 = debtSilo == _SILO0;
        debtInfo.debtInThisSilo = _silo == debtSilo;
    }

    function getDebtSilo(address _borrower) public view virtual returns (address debtSilo) {
        uint256 debtBal0 = IERC20(_DEBT_SHARE_TOKEN0).balanceOf(_borrower);
        uint256 debtBal1 = IERC20(_DEBT_SHARE_TOKEN1).balanceOf(_borrower);

        if (debtBal0 > 0 && debtBal1 > 0) revert DebtExistInOtherSilo();
        if (debtBal0 == 0 && debtBal1 == 0) return address(0);

        debtSilo = debtBal0 > debtBal1 ? _SILO0 : _SILO1;
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

    function _onlyDebtShareToken() internal view virtual {
        if (msg.sender != _DEBT_SHARE_TOKEN0 && msg.sender != _DEBT_SHARE_TOKEN1) revert OnlyDebtShareToken();
    }
}
