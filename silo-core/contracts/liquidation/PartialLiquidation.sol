// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISilo, ILiquidationProcess} from "../interfaces/ISilo.sol";
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloLendingLib} from "../lib/SiloLendingLib.sol";
import {Methods} from "../lib/Methods.sol";
import {CrossEntrancy} from "../lib/CrossEntrancy.sol";
import {Hook} from "../lib/Hook.sol";

import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";


/// @title PartialLiquidation module for executing liquidations
contract PartialLiquidation is IPartialLiquidation {
    /// @inheritdoc IPartialLiquidation
    function liquidationCall( // solhint-disable-line function-max-lines, code-complexity
        address _siloWithDebt, // TODO bug, we need to verify input
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
        ISiloConfig siloConfigCached = ISilo(_siloWithDebt).config();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo,
            IHookReceiver hookReceiverAfter
        ) = siloConfigCached.startAction(
            _siloWithDebt,
            _borrower,
            Hook.LIQUIDATION | Hook.BEFORE,
            abi.encodePacked(_collateralAsset, _debtAsset, _borrower, _debtToCover, _receiveSToken)
        );

        if (!debtInfo.debtPresent) revert UserIsSolvent();
        if (!debtInfo.debtInThisSilo) revert ISilo.ThereIsDebtInOtherSilo();

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        ISilo(_siloWithDebt).accrueInterest();
        ISilo(debtConfig.otherSilo).accrueInterest(); // TODO optimise if same silo

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

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
        ILiquidationProcess(_siloWithDebt).liquidationRepay(repayDebtAssets, _borrower, msg.sender);

        ILiquidationProcess(collateralConfig.silo).withdrawCollateralsToLiquidator(
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, _borrower, msg.sender, _receiveSToken
        );

        siloConfigCached.finishAction();

        if (address(hookReceiverAfter) != address(0)) {
            hookReceiverAfter.afterAction(
                Hook.LIQUIDATION | Hook.AFTER,
                abi.encodePacked(
                    _collateralAsset,
                    _debtAsset,
                    _borrower,
                    _debtToCover,
                    _receiveSToken,
                    withdrawCollateral, repayDebtAssets
                )
            );
        }
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
}
