// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISilo, ILiquidationProcess} from "../interfaces/ISilo.sol";
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";

import {SiloLendingLib} from "../lib/SiloLendingLib.sol";
import {Hook} from "../lib/Hook.sol";

import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";


/// @title PartialLiquidation module for executing liquidations
contract PartialLiquidation is IPartialLiquidation {
    using Hook for uint24;

    mapping(address silo => HookSetup) private _hooksSetup;

    function synchronizeHooks(address _hookReceiver, uint24 _hooksBefore, uint24 _hooksAfter) external {
        _hooksSetup[msg.sender].hookReceiver = _hookReceiver;
        _hooksSetup[msg.sender].hooksBefore = _hooksBefore;
        _hooksSetup[msg.sender].hooksAfter = _hooksAfter;
    }

    /// @inheritdoc IPartialLiquidation
    function liquidationCall( // solhint-disable-line function-max-lines, code-complexity
        address _siloWithDebt, // TODO bug - we need to verify if _siloWithDebt is real silo
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
        HookSetup memory hookSetupForSilo = _hooksSetup[_siloWithDebt];

        _beforeLiquidationHook(
            hookSetupForSilo,
            _siloWithDebt,
            _collateralAsset,
            _debtAsset,
            _borrower,
            _debtToCover,
            _receiveSToken
        );

        (
            ISiloConfig siloConfigCached,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(_siloWithDebt, _collateralAsset, _debtAsset, _borrower);

        { // too deep
            bool selfLiquidation = _borrower == msg.sender;
            uint256 withdrawAssetsFromCollateral;
            uint256 withdrawAssetsFromProtected;

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

            if (repayDebtAssets == 0) revert NoDebtToCover();
            // this two value were split from total collateral to withdraw, so we will not overflow
            unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }

            emit LiquidationCall(msg.sender, _receiveSToken);
            ILiquidationProcess(debtConfig.silo).liquidationRepay(repayDebtAssets, _borrower, msg.sender);

            ILiquidationProcess(collateralConfig.silo).withdrawCollateralsToLiquidator(
                withdrawAssetsFromCollateral, withdrawAssetsFromProtected, _borrower, msg.sender, _receiveSToken
            );
        }

        siloConfigCached.crossNonReentrantAfter();

        _afterLiquidationHook(
            hookSetupForSilo,
            _siloWithDebt,
            _collateralAsset,
            _debtAsset,
            _borrower,
            _debtToCover,
            _receiveSToken,
            withdrawCollateral,
            repayDebtAssets
        );
    }

    function hookSetup(address _silo) external view virtual returns (HookSetup memory) {
        return _hooksSetup[_silo];
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
        address _siloWithDebt,
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
        siloConfigCached = ISilo(_siloWithDebt).config();

        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = siloConfigCached.getConfigs(
            _siloWithDebt,
            _borrower,
            Hook.LIQUIDATION
        );

        if (!debtInfo.debtPresent) revert UserIsSolvent();
        if (!debtInfo.debtInThisSilo) revert ISilo.ThereIsDebtInOtherSilo();

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        ISilo(debtConfig.silo).accrueInterest();
        if (!debtInfo.sameAsset) ISilo(debtConfig.otherSilo).accrueInterest();

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }
    }

    function _beforeLiquidationHook(
        HookSetup memory _sharedStorage,
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken
    ) internal virtual {
        if (_sharedStorage.hookReceiver == address(0)) return;

        uint256 hookAction = Hook.BEFORE | Hook.LIQUIDATION;
        if (!_sharedStorage.hooksBefore.matchAction(hookAction)) return;

        IHookReceiver(_sharedStorage.hookReceiver).beforeAction(
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
        HookSetup memory _sharedStorage,
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken,
        uint256 _withdrawCollateral,
        uint256 _repayDebtAssets
    ) internal {
        if (_sharedStorage.hookReceiver == address(0)) return;

        uint256 hookAction = Hook.AFTER | Hook.LIQUIDATION;
        if (!_sharedStorage.hooksAfter.matchAction(hookAction)) return;

        IHookReceiver(_sharedStorage.hookReceiver).afterAction(
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
