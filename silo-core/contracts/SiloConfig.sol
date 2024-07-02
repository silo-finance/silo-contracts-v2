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

interface SiloConfigV2 {
    // TODOs:
    // 1. crossNonReentrantBefore() & crossNonReentrantAfter() should be called directly by each function
    // 2. Silo.accrueInterest() should be called directly by each function
    // 3. getDebtSilo() replaces all debt management. onDebtTransfer() and _openDebt() can be removed and `debtPresent`, `debtInSilo0` and 
    // `debtInThisSilo` can be calculated on the fly removing a need for external calls.
    // 5. `setCollateralSilo()` should be called only by switchCollateralTo() or when borrowing
    // same asset. Otherwise default state is enough.
    // 6. Split SiloConfig.getConfigs() & ConfigLib.orderConfigs() into multiple functions to avoid
    // complex IFs. Refactor getOrderedConfigs() into multiple functions so that `_action` is not needed.

    // #######################################
    // ########## REENTRANCY GUARDS ##########
    // #######################################

    /// TODO: should be called by all functions that change storage
    /// Called by:
    /// - Actions._executeOnLeverageCallBack()
    /// - ShareToken.transferFrom()
    /// - ShareToken.transfer()
    /// - SiloConfig.accrueInterestAndGetConfig()
    /// - SiloConfig.accrueInterestAndGetConfigOptimised()
    function crossNonReentrantBefore() external virtual;

    /// TODO: should be called by all functions that call crossNonReentrantBefore()
    /// Called by:
    /// - Actions.deposit()
    /// - Actions.withdraw()
    /// - Actions.borrow()
    /// - Actions.repay()
    /// - Actions.leverageSameAsset()
    /// - Actions.transitionCollateral()
    /// - Actions.switchCollateralTo()
    /// - ShareToken.transferFrom()
    /// - ShareToken.transfer()
    function crossNonReentrantAfter() external virtual;

    // #####################################
    // ########## DEBT MANAGEMENT ##########
    // #####################################

    /// Called by:
    /// - Actions.switchCollateralTo()
    /// - Actions.borrow()
    /// - Actions.leverageSameAsset()
    // function changeCollateralType(address _borrower, bool _switchToSameAsset)
    function setCollateralSilo(address _borrower, address _silo)
        internal
        onlySilo
        returns (DebtInfo memory debtInfo);

    /// - ShareDebtToken._afterTokenTransfer()
    function forbidDebtInTwoSilos(address _borrower) external view virtual returns (bool);

    // #######################################
    // ########## CONFIG MANAGEMENT ##########
    // #######################################

    // One less data point to keep in sync between Silo and DebtShareToken
    function getDebtSilo(address _borrower) external view virtual returns (address debtSilo) {
        uint256 debtBal0 = IERC20(_DEBT_SHARE_TOKEN0).balanceOf(_borrower);
        uint256 debtBal1 = IERC20(_DEBT_SHARE_TOKEN1).balanceOf(_borrower);

        if (debtBal0 > 0 && debtBal1 > 0) revert DebtInTwoSilos();
        if (debtBal0 == 0 && debtBal1 == 0) return address(0);

        debtSilo = debtBal0 > debtBal1 ? _SILO0 : _SILO1;
    }

    function getDebtInfo(
        address _silo,
        address _borrower,
        address _collateralSilo,
        address _debtSilo
    ) external view virtual returns (DebtInfo memory debtInfo) {
        debtInfo.debtPresent = _debtSilo != address(0);
        debtInfo.sameAsset = _collateralSilo == _debtSilo;
        debtInfo.debtInSilo0 = _debtSilo == _SILO0;
        debtInfo.debtInThisSilo = _silo == _debtSilo;
    }

    /// Called by:
    /// - Actions.withdraw()
    function getConfigForWithdraw(address _silo, address _borrower) external view virtual returns (
        ConfigData memory depositConfig,
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig,
        DebtInfo memory debtInfo
    ) {
        address collateralSilo = borrowerCollateralSilo[_borrower];
        address debtSilo = getDebtSilo(_borrower);
        
        depositConfig = getConfig(_silo);
        collateralConfig = getConfig(collateralSilo);
        debtConfig = getConfig(debtSilo);

        // if withdrawing collateral
        // if (_silo == collateralSilo) {
        // }
        // if withdrawing unrelated deposit, no need to load collateralConfig and debtConfig
        
        // debtInfo = getDebtInfo(_silo, _borrower, collateralSilo, debtSilo);
    }

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Actions.borrow() - collateralConfig/debtConfig/debtInfo
    /// - Actions.switchCollateralTo() - collateralConfig/debtConfig/debtInfo
    function getConfigsForBorrow(address _silo, address _borrower)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        address collateralSilo = borrowerCollateralSilo[_borrower];
        address debtSilo = getDebtSilo(_borrower);

        if (debtSilo != address(0) && debtSilo != _silo) revert WrongDebtSilo();

        collateralConfig = getConfig(collateralSilo);
        debtConfig = getConfig(_silo);
        // debtInfo = getDebtInfo(_silo, _borrower, collateralSilo, debtSilo);
    }

    /// Called by:
    /// - Actions.deposit()
    /// - Actions.repay()
    /// replaces: accrueInterestAndGetConfigOptimised()
    function getShareTokensAndAsset(address _silo, ISilo.CollateralType _collateralType)
        external
        view
        virtual
        returns (address collateralShareToken, address debtShareToken, address asset)
    {
        // another option is that Silo calls SiloConfig.getConfig(address(this)) directly
        ConfigData memory thisSiloConfig = getConfig(_silo);

        asset = thisSiloConfig.token;
        debtShareToken = thisSiloConfig.debtShareToken;
        collateralShareToken = _collateralType == ISilo.CollateralType.Collateral
            ? thisSiloConfig.collateralShareToken
            : thisSiloConfig.protectedShareToken;
    }

    /// Called by:
    /// - Silo.isSolvent()
    /// - SiloERC4626Lib.maxWithdraw()
    /// - SiloLendingLib.maxBorrow()
    /// - SiloLensLib.borrowPossible()
    /// - SiloLensLib.getLtv()
    /// - ShareToken._callOracleBeforeQuote()
    /// - PartialLiquidation._fetchConfigs() (liquidationCall)
    /// - PartialLiquidation.maxLiquidation()
    /// - [NEW] Actions.transitionCollateral()
    function getConfigsForView(address _silo, address _borrower, uint256 _action)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        debtInfo = _debtsInfo[_borrower];

        (collateralConfig, debtConfig) = _getOrderedConfigs(_silo, debtInfo, _action);
    }

    /// Called by:
    /// - Actions.leverageSameAsset() - debtConfig/debtInfo
    function getConfigAndDebtInfo(address _silo, address _borrower)
        external
        view
        virtual
        returns (ConfigData memory debtConfig, DebtInfo memory debtInfo);

    // ####################################
    // ########## SIMPLE GETTERS ##########
    // ####################################

    function getConfig(address _silo) external view virtual returns (ConfigData memory);
    function crossReentrantStatus() external view virtual returns (bool entered, uint256 status);
    function getSilos() external view returns (address silo0, address silo1);
    function getShareTokens(address _silo)
        external
        view
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken);
    function getAssetForSilo(address _silo) external view virtual returns (address asset);
    function getFeesWithAsset(address _silo)
        external
        view
        virtual
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset);
}

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

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Actions._executeOnLeverageCallBack()
    /// - ShareToken.transferFrom()
    /// - ShareToken.transfer()
    /// - SiloConfig.accrueInterestAndGetConfig()
    /// - SiloConfig.accrueInterestAndGetConfigOptimised()
    function crossNonReentrantBefore(uint256 _action) external virtual {
        if (_action.matchAction(CrossEntrancy.ENTERED_FROM_LEVERAGE)) {
            _onlySilo();
        } else {
            _onlySiloOrTokenOrHookReceiver();
        }

        _crossNonReentrantBefore(_action);
    }

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Actions.deposit()
    /// - Actions.withdraw()
    /// - Actions.borrow()
    /// - Actions.repay()
    /// - Actions.leverageSameAsset()
    /// - Actions.transitionCollateral()
    /// - Actions.switchCollateralTo()
    /// - ShareToken.transferFrom()
    /// - ShareToken.transfer()
    function crossNonReentrantAfter() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        _crossNonReentrantAfter();
    }

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - ShareDebtToken._beforeTokenTransfer()
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

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - ShareDebtToken._afterTokenTransfer()
    function closeDebt(address _borrower) external virtual {
        if (msg.sender != _SILO0 && msg.sender != _SILO1 &&
            msg.sender != _DEBT_SHARE_TOKEN0 && msg.sender != _DEBT_SHARE_TOKEN1
        ) revert OnlySiloOrDebtShareToken();

        delete _debtsInfo[_borrower];
    }

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Actions.transitionCollateral()
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

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Actions.deposit()
    /// - Actions.repay()
    function accrueInterestAndGetConfigOptimised(
        uint256 _action,
        ISilo.CollateralType _collateralType
    ) external virtual returns (address shareToken, address asset) {
        _crossNonReentrantBefore(_action);
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

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Actions.withdraw()
    /// - Actions.borrow()
    /// - Actions.leverageSameAsset()
    /// - Actions.switchCollateralTo()
    function accrueInterestAndGetConfigs(address _silo, address _borrower, uint256 _action)
        external
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        _crossNonReentrantBefore(_action);

        if (_action.matchAction(Hook.BORROW)) {
            debtInfo = _openDebt(_borrower, _action);
        } else if (_action.matchAction(Hook.SWITCH_COLLATERAL)) {
            debtInfo = _changeCollateralType(_borrower, _action.matchAction(Hook.SAME_ASSET));
        } else {
            // TODO looks like anyone can raise flag if there is no action taken?
            debtInfo = _debtsInfo[_borrower];
        }

        _callAccrueInterest(_silo);

        (collateralConfig, debtConfig) = _getOrderedConfigs(_silo, debtInfo, _action);
    }

    /// @inheritdoc ISiloConfig
    /// Called by:
    /// - Silo.isSolvent()
    /// - SiloERC4626Lib.maxWithdraw()
    /// - SiloLendingLib.maxBorrow()
    /// - SiloLensLib.borrowPossible()
    /// - SiloLensLib.getLtv()
    /// - ShareToken._callOracleBeforeQuote()
    /// - PartialLiquidation._fetchConfigs() (liquidationCall)
    /// - PartialLiquidation.maxLiquidation()
    function getConfigs(address _silo, address _borrower, uint256 _action)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        debtInfo = _debtsInfo[_borrower];

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
    /// Called by:
    /// - Silo.asset()
    /// - Silo.maxFlashLoan()
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
    /// Called by:
    /// - Silo.initialize()
    /// - Silo.getCollateralAssets()
    /// - Silo.getDebtAssets()
    /// - Silo.maxRepay()
    /// - Silo.maxRepayShares()
    /// - Silo._getTotalAssetsAndTotalSharesWithInterest()
    /// - Silo._accrueInterest()
    /// - InterestRateModelV2.getConfig()
    /// - Actions.flashLoan()
    /// - Actions.updateHooks()
    /// - SiloLendingLib.getLiquidity()
    /// - SiloLensLib.getMaxLtv()
    /// - SiloLensLib.getLt()
    /// - ShareToken.decimals()
    /// - ShareToken.name()
    /// - ShareToken.symbol()
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
}
