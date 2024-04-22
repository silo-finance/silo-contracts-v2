// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {IHookReceiver} from "./utils/hook-receivers/interfaces/IHookReceiver.sol";
import {Methods} from "./lib/Methods.sol";
import {CrossEntrancy} from "./lib/CrossEntrancy.sol";
import {Hook} from "./lib/Hook.sol";

// solhint-disable var-name-mixedcase

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig {
    using Hook for IHookReceiver;

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

    address private immutable _HOOK_RECEIVER0;

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

    address private immutable _HOOK_RECEIVER1;

    bool private immutable _CALL_BEFORE_QUOTE1;

    // TODO do we need events for this? this is internal state only
    mapping (address borrower => DebtInfo debtInfo) internal _debtsInfo;

    HooksSetup public hooksSetup;
    uint256 _crossReentrantStatus;

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

        _HOOK_RECEIVER0 = _configData0.hookReceiver;

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

        _HOOK_RECEIVER1 = _configData1.hookReceiver;

        _CALL_BEFORE_QUOTE1 = _configData1.callBeforeQuote;
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

    /// @inheritdoc ISiloConfig
    function finishAction(address _silo, uint256 _hookAction) external virtual returns (IHookReceiver hookReceiverAfter) {
        _onlySiloOrTokenOrLiquidation();

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _crossReentrantStatus = CrossEntrancy.NOT_ENTERED;

        hookReceiverAfter = _getHookAfterAddress(_silo == _SILO0, _hookAction);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function crossReentrancyGuardEntered() external view virtual returns (bool) {
        return _crossReentrantStatus != CrossEntrancy.NOT_ENTERED;
    }

    /// @inheritdoc ISiloConfig
    function crossLeverageGuard(uint256 _entranceFrom) external virtual {
        _onlySilo();

        // this case is for been able to set guard after deposit, when we still inside leverege
        if (_crossReentrantStatus == CrossEntrancy.NOT_ENTERED && _entranceFrom == CrossEntrancy.ENTERED) {
            // Any calls to nonReentrant after this point will fail
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        if (_crossReentrantStatus == CrossEntrancy.ENTERED && _entranceFrom == CrossEntrancy.ENTERED_FROM_LEVERAGE) {
            // we need to be inside leverage and before callback, we mark our status
            _crossReentrantStatus = CrossEntrancy.ENTERED_FROM_LEVERAGE;
            return;
        }

        revert CrossReentrantCall();
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
    function startAction(address _borrower, uint256 _hook, bytes calldata _input)
        external
        virtual
        returns ( // TODO maybe bytes config for both? and decode to one/two?
            ConfigData memory collateralConfig,
            ConfigData memory debtConfig,
            DebtInfo memory debtInfo
        )
    {
        _onlySilo();

        return startAction(msg.sender, _borrower, _hook, _input);
    }

    /// @inheritdoc ISiloConfig
    function startAction(
        address _silo,
        address _borrower,
        uint256 _hookAction, // this will also determine method
        bytes calldata _input
    )
        public
        virtual
        returns ( // TODO maybe bytes config for both? and decode to one/two?
            ConfigData memory collateralConfig,
            ConfigData memory debtConfig,
            DebtInfo memory debtInfo
        )
    {
        _onlySiloOrTokenOrLiquidation();
        
        _crossNonReentrantBefore(_beforeActionHookCall(_silo, _hookAction, _input), _hookAction);

        if (_hookAction & Hook.SHARE_TOKEN_TRANSFER != 0) {
            // share token transfer does not need configs
            return (collateralConfig, debtConfig, debtInfo);
        } else if (_hookAction & Hook.FLASH_LOAN != 0) {
            // flash loan does not need configs
            return (collateralConfig, debtConfig, debtInfo);
        } else if (_hookAction & Hook.BORROW != 0) {
            debtInfo = _openDebt(_borrower, _hookAction);
        } else if (_hookAction & Hook.SWITCH_COLLATERAL != 0) {
            debtInfo = _changeCollateralType(_borrower, _hookAction & Hook.SAME_ASSET != 0);
        } else {
            debtInfo = _debtsInfo[_borrower];
        }

        (collateralConfig, debtConfig) = _getConfigs(_silo, _hookAction, debtInfo);
    }

    function getConfigs(address _silo)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig)
    {
        (collateralConfig, debtConfig) = _getConfigs(_silo, 0, _debtsInfo[address(0)]); // TODO
    }

    function getConfigs(address _silo, address _borrower, uint256 _hook)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        debtInfo = _debtsInfo[_borrower];
        (collateralConfig, debtConfig) = _getConfigs(_silo, _hook, debtInfo);
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

    // solhint-disable-next-line function-max-lines, code-complexity
    function _getConfigs(address _silo, uint256 _hook, DebtInfo memory _debtInfo)
        internal
        view
        virtual
        returns (ConfigData memory collateral, ConfigData memory debt)
    {
        bool callForSilo0 = _silo == _SILO0;
        if (!callForSilo0 && _silo != _SILO1) revert WrongSilo();

        collateral = _silo0ConfigData();
        debt = _silo1ConfigData();

        if (!_debtInfo.debtPresent) {
            if (_hook & Hook.BORROW & Hook.SAME_ASSET != 0) {
                return callForSilo0 ? (collateral, collateral) : (debt, debt);
            } else if (_hook & Hook.BORROW & Hook.TWO_ASSETS != 0) {
                return callForSilo0 ? (debt, collateral) : (collateral, debt);
            } else {
                return callForSilo0 ? (collateral, debt) : (debt, collateral);
            }
        } else if (_hook & Hook.WITHDRAW != 0) {
            _debtInfo.debtInThisSilo = callForSilo0 == _debtInfo.debtInSilo0;

            if (_debtInfo.sameAsset) {
                if (_debtInfo.debtInSilo0) {
                    return callForSilo0
                        ? (collateral, collateral)
                        : (debt, collateral); // only deposit
                } else {
                    return callForSilo0
                        ? (collateral, debt) // only deposit
                        : (debt, debt);
                }
            } else {
                if (_debtInfo.debtInSilo0) {
                    return callForSilo0
                        ? (collateral, debt)
                        : (debt, collateral); // only deposit
                } else {
                    return callForSilo0
                        ? (collateral, debt) // only deposit
                        : (debt, collateral);
                }
            }
        }

        if (_debtInfo.debtInSilo0) {
            _debtInfo.debtInThisSilo = callForSilo0;

            if (_debtInfo.sameAsset) {
                debt = collateral;
            } else {
                (collateral, debt) = (debt, collateral);
            }
        } else {
            _debtInfo.debtInThisSilo = !callForSilo0;

            if (_debtInfo.sameAsset) {
                collateral = debt;
            }
        }

        return (collateral, debt);
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
            hookReceiver: _HOOK_RECEIVER0,
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
            liquidationModule: _LIQUIDATION_MODULE,
            hookReceiver: _HOOK_RECEIVER1,
            callBeforeQuote: _CALL_BEFORE_QUOTE1
        });
    }

    function _forbidDebtInTwoSilos(bool _debtInSilo0) internal view virtual {
        if (msg.sender == _DEBT_SHARE_TOKEN0 && _debtInSilo0) return;
        if (msg.sender == _DEBT_SHARE_TOKEN1 && !_debtInSilo0) return;

        revert DebtExistInOtherSilo();
    }

    function _getHookBeforeAddress(bool _callFromSilo0, uint256 _hookAction)
        internal
        view
        virtual
        returns (IHookReceiver hookReceiver)
    {
        hookReceiver = IHookReceiver(_callFromSilo0 ? _HOOK_RECEIVER0 : _HOOK_RECEIVER1);

        if (address(hookReceiver) != address(0)) {
            uint256 hookTriggers = _callFromSilo0 ? hooksSetup.silo0HooksBefore : hooksSetup.silo1HooksBefore;
            return hookTriggers & (_hookAction | Hook.BEFORE) == 0 ? IHookReceiver(address(0)) : hookReceiver;
        }
    }
    
    function _getHookAfterAddress(bool _callFromSilo0, uint256 _hookAction)
        internal
        view
        virtual
        returns (IHookReceiver hookReceiver)
    {
        hookReceiver = IHookReceiver(_callFromSilo0 ? _HOOK_RECEIVER0 : _HOOK_RECEIVER1);

        if (address(hookReceiver) != address(0)) {
            uint256 hookTriggers = _callFromSilo0 ? hooksSetup.silo0HooksAfter : hooksSetup.silo1HooksAfter;
            return hookTriggers & (_hookAction | Hook.AFTER) == 0 ? IHookReceiver(address(0)) : hookReceiver;
        }
    }

    function _beforeActionHookCall(address _silo, uint256 _hookAction, bytes memory _input)
        internal
        returns (uint256 crossReentrantStatus)
    {
        IHookReceiver hookReceiverBefore = _getHookBeforeAddress(_silo == _SILO0, _hookAction);
        crossReentrantStatus = _crossReentrantStatus;

        // there should be no hook calls, if you inside action eg inside leverage, liquidation etc
        if (address(hookReceiverBefore) != address(0) && crossReentrantStatus == CrossEntrancy.NOT_ENTERED) {
            hookReceiverBefore.beforeActionCall(_silo, _hookAction, _input);
        }
    }

    /// @notice it will change collateral for existing debt, only silo can call it
    /// @return debtInfo details about `borrower` debt after the change
    function _changeCollateralType(address _borrower, bool _sameAsset)
        internal
        virtual
        returns (DebtInfo memory debtInfo)
    {
        _onlySilo();

        debtInfo = _debtsInfo[_borrower];

        if (!debtInfo.debtPresent) revert NoDebt();
        if (debtInfo.sameAsset == _sameAsset) revert CollateralTypeDidNotChanged();

        _debtsInfo[_borrower].sameAsset = _sameAsset;
        debtInfo.sameAsset = _sameAsset;
    }

    function _openDebt(address _borrower, uint256 _hook) internal virtual returns (DebtInfo memory debtInfo) {
        _onlySilo();

        debtInfo = _debtsInfo[_borrower];

        if (!debtInfo.debtPresent) {
            debtInfo.debtPresent = true;
            debtInfo.sameAsset = _hook & Hook.SAME_ASSET != 0;
            debtInfo.debtInSilo0 = msg.sender == _SILO0;

            _debtsInfo[_borrower] = debtInfo;
        }
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

    function _crossNonReentrantBefore(uint256 _crossReentrantStatusCached, uint256 _hookAction) internal virtual {
        // On the first call to nonReentrant, _status will be CrossEntrancy.NOT_ENTERED
        if (_crossReentrantStatusCached == CrossEntrancy.NOT_ENTERED) {
            // Any calls to nonReentrant after this point will fail
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        if (_crossReentrantStatusCached == CrossEntrancy.ENTERED_FROM_LEVERAGE && _hookAction == Hook.DEPOSIT) {
            // on leverage, entrance from deposit is allowed, but allowance is removed when we back to Silo
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        revert CrossReentrantCall();
    }
}
