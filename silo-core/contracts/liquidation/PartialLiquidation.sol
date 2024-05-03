// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo, ILiquidationProcess} from "../interfaces/ISilo.sol";
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";

import {SiloLendingLib} from "../lib/SiloLendingLib.sol";
import {Hook} from "../lib/Hook.sol";

import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";


/// @title PartialLiquidation module for executing liquidations
contract PartialLiquidation is IPartialLiquidation, Initializable {
    using Hook for uint24;

    ISiloConfig public siloConfig;

    HookSetup public hooksSetup;

    address private _silo0;
    address private _silo1;

    constructor() {
        _disableInitializers();
    }

    function initialise(address _siloConfig) external initializer {
        siloConfig = ISiloConfig(_siloConfig);
        (_silo0, _silo1) = siloConfig.getSilos();
    }

    function synchronizeHooks(address _hookReceiver, uint24 _hooksBefore, uint24 _hooksAfter) external {
        if (msg.sender != _silo0 && msg.sender != _silo1) revert OnlySilo();

        hooksSetup.hookReceiver = _hookReceiver;
        hooksSetup.hooksBefore = _hooksBefore;
        hooksSetup.hooksAfter = _hooksAfter;
    }

    /// @inheritdoc IPartialLiquidation
    function liquidationCall( // solhint-disable-line function-max-lines, code-complexity
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken
    )
        external
        virtual
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        HookSetup memory hookSetupForSilo = hooksSetup;

        (
            ISiloConfig siloConfigCached,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(_collateralAsset, _debtAsset, _borrower);

        _beforeLiquidationHook(
            hookSetupForSilo,
            debtConfig.silo,
            _collateralAsset,
            _debtAsset,
            _borrower,
            _debtToCover,
            _receiveSToken
        );

        { // too deep
            uint256 withdrawAssetsFromCollateral;
            uint256 withdrawAssetsFromProtected;

            { // too deep
                bool selfLiquidation = _borrower == msg.sender;

                (
                    withdrawAssetsFromCollateral, withdrawAssetsFromProtected, repayDebtAssets
                ) = PartialLiquidationExecLib.getExactLiquidationAmounts(
                    collateralConfig,
                    debtConfig,
                    _borrower,
                    _debtToCover,
                    selfLiquidation ? 0 : collateralConfig.liquidationFee,
                    selfLiquidation
                );
            }

            if (repayDebtAssets == 0) revert NoDebtToCover();
            // this two value were split from total collateral to withdraw, so we will not overflow
            unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }

            emit LiquidationCall(msg.sender, _receiveSToken);
            ILiquidationProcess(siloConfigCached).liquidationRepay(repayDebtAssets, _borrower, msg.sender);

            ILiquidationProcess(collateralConfig.silo).withdrawCollateralsToLiquidator(
                withdrawAssetsFromCollateral,
                withdrawAssetsFromProtected,
                _borrower,
                msg.sender,
                _receiveSToken
            );
        }

        siloConfigCached.crossNonReentrantAfter();

        _afterLiquidationHook(
            hookSetupForSilo,
            siloConfigCached,
            _collateralAsset,
            _debtAsset,
            _borrower,
            _debtToCover,
            _receiveSToken,
            withdrawCollateral,
            repayDebtAssets
        );
    }

    /// @inheritdoc IPartialLiquidation
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        return PartialLiquidationExecLib.maxLiquidation(ISilo(_siloWithDebt), _borrower);
    }

    function _fetchConfigs(
        address _collateralAsset,
        address _debtAsset,
        address _borrower
    )
        internal
        returns (
            ISiloConfig siloConfigCached,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        siloConfigCached = siloConfig;

        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = siloConfigCached.getConfigs(
            _silo0,
            _borrower,
            Hook.LIQUIDATION
        );

        if (!debtInfo.debtPresent) revert UserIsSolvent();

        if (!debtInfo.debtInThisSilo) {
            (collateralConfig, debtConfig) = (debtConfig, collateralConfig);
        }

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        ISilo(debtConfig.silo).accrueInterest();

        if (!debtInfo.sameAsset) {
            ISilo(debtConfig.otherSilo).accrueInterest();

            if (collateralConfig.callBeforeQuote) {
                ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
            }

            if (debtConfig.callBeforeQuote) {
                ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
            }
        }
    }

    function _beforeLiquidationHook(
        HookSetup memory _hookSetup,
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken
    ) internal virtual {
        if (_hookSetup.hookReceiver == address(0)) return;

        uint256 hookAction = Hook.BEFORE | Hook.LIQUIDATION;
        if (!_hookSetup.hooksBefore.matchAction(hookAction)) return;

        IHookReceiver(_hookSetup.hookReceiver).beforeAction(
            _siloWithDebt,
            hookAction,
            abi.encodePacked(
                _siloWithDebt,
                _collateralAsset,
                _debtAsset,
                _borrower,
                _debtToCover,
                _receiveSToken
            )
        );
    }

    function _afterLiquidationHook(
        HookSetup memory _hookSetup,
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken,
        uint256 _withdrawCollateral,
        uint256 _repayDebtAssets
    ) internal {
        if (_hookSetup.hookReceiver == address(0)) return;

        uint256 hookAction = Hook.AFTER | Hook.LIQUIDATION;
        if (!_hookSetup.hooksAfter.matchAction(hookAction)) return;

        IHookReceiver(_hookSetup.hookReceiver).afterAction(
            _siloWithDebt,
            hookAction,
            abi.encodePacked(
                _siloWithDebt,
                _collateralAsset,
                _debtAsset,
                _borrower,
                _debtToCover,
                _receiveSToken,
                _withdrawCollateral,
                _repayDebtAssets
            )
        );
    }
}
