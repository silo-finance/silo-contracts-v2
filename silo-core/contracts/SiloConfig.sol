// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {Methods} from "./lib/Methods.sol";
import {CrossEntrancy} from "./lib/CrossEntrancy.sol";

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

    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private _crossReentrantStatus;

    HooksSetup public hooksSetup;

    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData0 silo configuration data for token0
    /// @param _configData1 silo configuration data for token1
    constructor(uint256 _siloId, ConfigData memory _configData0, ConfigData memory _configData1) {
        _crossReentrantStatus = CrossEntrancy.NOT_ENTERED;

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

    function updateHooks(uint128 _hooksBitmap) external {
        if (msg.sender == _HOOK_RECEIVER0) {
            hooksSetup.silo0Hooks = _hooksBitmap;
            emit HooksUpdated(_hooksBitmap);
        } else if (msg.sender == _HOOK_RECEIVER1) {
            hooksSetup.silo1Hooks = _hooksBitmap;
            emit HooksUpdated(_hooksBitmap);
        }

        revert OnlyHookReceiver();
    }

    /// @inheritdoc ISiloConfig
    function openDebt(address _borrower, bool _sameAsset)
        external
        virtual
        returns (ConfigData memory, ConfigData memory, DebtInfo memory)
    {
        _onlySilo();

        DebtInfo memory debtInfo = _debtsInfo[_borrower];

        if (!debtInfo.debtPresent) {
            debtInfo.debtPresent = true;
            debtInfo.sameAsset = _sameAsset;
            debtInfo.debtInSilo0 = msg.sender == _SILO0;

            _debtsInfo[_borrower] = debtInfo;
        }

        return _getConfigs(msg.sender, 0 /* method does not mather when debt open */, debtInfo);
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

    function changeCollateralType(address _borrower, bool _sameAsset)
        external
        virtual
        returns (ConfigData memory, ConfigData memory, DebtInfo memory debtInfo)
    {
        if (msg.sender != _SILO0 && msg.sender != _SILO1) revert OnlySilo();

        debtInfo = _debtsInfo[_borrower];

        if (!debtInfo.debtPresent) revert NoDebt();
        if (debtInfo.sameAsset == _sameAsset) revert CollateralTypeDidNotChanged();

        _debtsInfo[_borrower].sameAsset = _sameAsset;
        debtInfo.sameAsset = _sameAsset;

        return _getConfigs(msg.sender, 0 /* method does not mather when debt open */, debtInfo);
    }

    /// @inheritdoc ISiloConfig
    function crossLeverageStart() internal virtual {
        _onlySilo();

        if (_crossReentrantStatus == CrossEntrancy.ENTERED) {
            // we need to be inside leverage and before callback, we mark our status
            _crossReentrantStatus = CrossEntrancy.ENTERED_FROM_LEVERAGE;
        } else revert CrossReentrantCall();
    }

    function _crossNonReentrantBefore(uint256 _hook) internal virtual {
        // On the first call to nonReentrant, _status will be CrossEntrancy.NOT_ENTERED
        if (_crossReentrantStatus == CrossEntrancy.NOT_ENTERED) {
            // Any calls to nonReentrant after this point will fail
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        if (_crossReentrantStatus == CrossEntrancy.ENTERED_FROM_LEVERAGE && _hook == Hook.BEFORE_DEPOSIT) {
            // on leverage, entrance from deposit is allowed, but allowance is removed
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        revert CrossReentrantCall();
    }

    /// @inheritdoc ISiloConfig
    function crossNonReentrantAfter() external virtual {
        _onlySiloTokenOrLiquidation();

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _crossReentrantStatus = CrossEntrancy.NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function crossReentrancyGuardEntered() external view virtual returns (bool) {
        return _crossReentrantStatus == CrossEntrancy.ENTERED;
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
    function startAction(
        address _silo,
        address _borrower,
        uint256 _hook, // this will also determine method
        bytes calldata _input
    )
        external
        view
        virtual
        returns ( // TODO in theory, we could returns bytes, and on other side decode to two or one config
            ConfigData memory collateralConfig,
            ConfigData memory debtConfig,
            DebtInfo memory debtInfo,
            IHookReceiver hookReceiverAfter
        )
    {
        _onlySiloTokenOrLiquidation();

        (IHookReceiver hookReceiverBefore, hookReceiverAfter) = _isHookCallNeeded(_silo == _SILO0, _hook);
        if (address(hookReceiverBefore) != address(0)) hookReceiverBefore.beforeAction(_silo, _hook, _input);

        _crossNonReentrantBefore(_hook);

        (collateralConfig, debtConfig, debtInfo) = _getConfigs(_silo, _hook, _debtsInfo[_borrower]);
    }

    function getConfigs(address _silo, address _borrower, uint256 _method)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo)
    {
        return _getConfigs(_silo, _method, _debtsInfo[_borrower]);
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
                hookReceiver: _HOOK_RECEIVER0,
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
                hookReceiver: _HOOK_RECEIVER1,
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

    // solhint-disable-next-line function-max-lines, code-complexity
    function _getConfigs(address _silo, uint256 _method, DebtInfo memory _debtInfo)
        internal
        view
        virtual
        returns (ConfigData memory collateral, ConfigData memory debt, DebtInfo memory)
    {
        bool callForSilo0 = _silo == _SILO0;
        if (!callForSilo0 && _silo != _SILO1) revert WrongSilo();

        collateral = ConfigData({
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

        debt = ConfigData({
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

        if (!_debtInfo.debtPresent) {
            if (_method == Methods.BORROW_SAME_ASSET) {
                return callForSilo0 ? (collateral, collateral, _debtInfo) : (debt, debt, _debtInfo);
            } else if (_method == Methods.BORROW_TWO_ASSETS) {
                return callForSilo0 ? (debt, collateral, _debtInfo) : (collateral, debt, _debtInfo);
            } else {
                return callForSilo0 ? (collateral, debt, _debtInfo) : (debt, collateral, _debtInfo);
            }
        } else if (_method == Methods.WITHDRAW) {
            _debtInfo.debtInThisSilo = callForSilo0 == _debtInfo.debtInSilo0;

            if (_debtInfo.sameAsset) {
                if (_debtInfo.debtInSilo0) {
                    return callForSilo0
                        ? (collateral, collateral, _debtInfo)
                        : (debt, collateral, _debtInfo); // only deposit
                } else {
                    return callForSilo0
                        ? (collateral, debt, _debtInfo) // only deposit
                        : (debt, debt, _debtInfo);
                }
            } else {
                if (_debtInfo.debtInSilo0) {
                    return callForSilo0
                        ? (collateral, debt, _debtInfo)
                        : (debt, collateral, _debtInfo); // only deposit
                } else {
                    return callForSilo0
                        ? (collateral, debt, _debtInfo) // only deposit
                        : (debt, collateral, _debtInfo);
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

        return (collateral, debt, _debtInfo);
    }

    function _forbidDebtInTwoSilos(bool _debtInSilo0) internal view virtual {
        if (msg.sender == _DEBT_SHARE_TOKEN0 && _debtInSilo0) return;
        if (msg.sender == _DEBT_SHARE_TOKEN1 && !_debtInSilo0) return;

        revert DebtExistInOtherSilo();
    }

    function _onlySiloTokenOrLiquidation() internal view virtual {
        if (msg.sender == _SILO0 ||
            msg.sender == _SILO1 ||
            msg.sender == _LIQUIDATION_MODULE ||
            msg.sender == _COLLATERAL_SHARE_TOKEN0 ||
            msg.sender == _COLLATERAL_SHARE_TOKEN1 ||
            msg.sender == _PROTECTED_COLLATERAL_SHARE_TOKEN0 ||
            msg.sender == _PROTECTED_COLLATERAL_SHARE_TOKEN1 ||
            msg.sender == _DEBT_SHARE_TOKEN0 ||
            msg.sender == _DEBT_SHARE_TOKEN1
        ) {
            return;
        } else revert OnlySiloOrLiquidationModule();
    }

    function _onlySilo() internal view virtual {
        if (msg.sender != _SILO0 && msg.sender != _SILO1) revert OnlySilo();
    }

    function _isHookCallNeeded(bool _callFromSilo0, uint256 _hook)
        internal
        view
        virtual
        returns (IHookReceiver hookReceiverBefore, IHookReceiver hookReceiverAfter)
    {
        address hookReceiver = _callFromSilo0 ? _HOOK_RECEIVER0 : _HOOK_RECEIVER1;

        if (hookReceiver != address(0)) {
            HookSetup memory setup = hooksSetup;

            uint256 hooksToTrigger = _callFromSilo0 ? setup.silo0HooksBefore : setup.silo1HooksBefore;
            hookReceiverBefore = IHookReceiver(hooksToTrigger & _hook == 0 ? address(0) : hookReceiver);

            hooksToTrigger = _callFromSilo0 ? setup.silo0HooksAfter : setup.silo1HooksAfter;
            hookReceiverAfter = IHookReceiver(hooksToTrigger & _hook == 0 ? address(0) : hookReceiver);
        }
    }
}
