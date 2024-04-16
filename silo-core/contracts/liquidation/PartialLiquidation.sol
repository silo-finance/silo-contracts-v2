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
    // solhint-disable-line function-max-lines, code-complexity
    /// @inheritdoc IPartialLiquidation
    function liquidationCall(LiquidationCallParams memory _params) // TODO bug, we need to verify input silo
        external
        virtual
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        ISiloConfig siloConfigCached = ISilo(_params.siloWithDebt).config();

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        IHookReceiver hookReceiverAfter;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;

            (
                collateralConfig, debtConfig, debtInfo, hookReceiverAfter
            ) = siloConfigCached.startActionFor(
                _params.siloWithDebt,
                _params.borrower,
                Hook.LIQUIDATION | Hook.BEFORE,
                abi.encode(_params)
            );

            if (!debtInfo.debtPresent) revert UserIsSolvent();
            if (!debtInfo.debtInThisSilo) revert ISilo.ThereIsDebtInOtherSilo();
        }

        if (_params.collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();

        ISilo(_params.siloWithDebt).accrueInterest();
        ISilo(debtConfig.otherSilo).accrueInterest(); // TODO optimise if same silo

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromProtected;

        { // too deep
            bool selfLiquidation = _params.borrower == msg.sender;

            (
                withdrawAssetsFromCollateral, withdrawAssetsFromProtected, repayDebtAssets
            ) = PartialLiquidationExecLib.getExactLiquidationAmounts(
                collateralConfig,
                debtConfig,
                _params.borrower,
                _params.debtToCover,
                selfLiquidation ? 0 : collateralConfig.liquidationFee,
                selfLiquidation
            );
        }

        if (repayDebtAssets == 0) revert NoDebtToCover();
        // this two value were split from total collateral to withdraw, so we will not overflow
        unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }

        emit LiquidationCall(msg.sender, _params.receiveSToken);
        ILiquidationProcess(_params.siloWithDebt).liquidationRepay(repayDebtAssets, _params.borrower, msg.sender);

        ILiquidationProcess(collateralConfig.silo).withdrawCollateralsToLiquidator(
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, _params.borrower, msg.sender, _params.receiveSToken
        );

        siloConfigCached.finishAction();

        if (address(hookReceiverAfter) != address(0)) {
            hookReceiverAfter.afterAction(
                _params.siloWithDebt,
                Hook.LIQUIDATION | Hook.AFTER,
                abi.encode(_params, withdrawCollateral, repayDebtAssets)
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
