// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {PartialLiquidationLib} from "./PartialLiquidationLib.sol";

library PartialLiquidationExecLib {
    /// @dev it will be user responsibility to check profit, this method expect interest to be already accrued
    function getExactLiquidationAmounts(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _maxDebtToCover,
        uint256 _liquidationFee
    )
        external
        view
        returns (
            uint256 withdrawAssetsFromCollateral,
            uint256 withdrawAssetsFromProtected,
            uint256 repayDebtAssets,
            bytes4 customError
        )
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations({
            _collateralConfig: _collateralConfig,
            _debtConfig: _debtConfig,
            _borrower: _user,
            _oracleType: ISilo.OracleType.Solvency,
            _accrueInMemory: ISilo.AccrueInterestInMemory.No,
            _debtShareBalanceCached:0 /* no cached balance */
        });

        uint256 borrowerCollateralToLiquidate;

        (
            borrowerCollateralToLiquidate, repayDebtAssets, customError
        ) = liquidationPreview(
            ltvData,
            PartialLiquidationLib.LiquidationPreviewParams({
                collateralLt: _collateralConfig.lt,
                collateralConfigAsset: _collateralConfig.token,
                debtConfigAsset: _debtConfig.token,
                maxDebtToCover: _maxDebtToCover,
                liquidationTargetLtv: _collateralConfig.liquidationTargetLtv,
                liquidationFee: _liquidationFee
            })
        );

        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected
        ) = PartialLiquidationLib.splitReceiveCollateralToLiquidate(
            borrowerCollateralToLiquidate, ltvData.borrowerProtectedAssets
        );
    }

    /// @dev debt keeps growing over time, so when dApp use this view to calculate max, tx should never revert
    /// because actual max can be only higher
    // solhint-disable-next-line function-max-lines
    function maxLiquidation(ISiloConfig _siloConfig, address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired)
    {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _siloConfig.getConfigsForSolvency(_borrower);

        if (debtConfig.silo == address(0)) {
            return (0, 0, false);
        }

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig,
            debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            0 /* no cached balance */
        );

        if (ltvData.borrowerDebtAssets == 0) return (0, 0, false);

        (
            uint256 sumOfCollateralValue, uint256 debtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, collateralConfig.token, debtConfig.token);

        uint256 sumOfCollateralAssets = ltvData.borrowerProtectedAssets + ltvData.borrowerCollateralAssets;

        if (sumOfCollateralValue == 0) return (sumOfCollateralAssets, ltvData.borrowerDebtAssets, false);

        uint256 ltvInDp = SiloSolvencyLib.ltvMath(debtValue, sumOfCollateralValue);
        if (ltvInDp <= collateralConfig.lt) return (0, 0, false); // user solvent

        (collateralToLiquidate, debtToRepay) = PartialLiquidationLib.maxLiquidation(
            sumOfCollateralAssets,
            sumOfCollateralValue,
            ltvData.borrowerDebtAssets,
            debtValue,
            collateralConfig.liquidationTargetLtv,
            collateralConfig.liquidationFee
        );

        // maxLiquidation() can underestimate collateral by `PartialLiquidationLib._UNDERESTIMATION`,
        // when we do that, actual collateral that we will transfer will match exactly liquidity,
        // but we will liquidate higher value by 1 or 2, then sTokenRequired will return false,
        // but we can not withdraw (because we will be short by 2) solution is to include this 2wei here
        unchecked {
            // safe to uncheck, because we underestimated this value in a first place by _UNDERESTIMATION
            uint256 overestimatedCollateral = collateralToLiquidate + PartialLiquidationLib._UNDERESTIMATION;
            sTokenRequired = overestimatedCollateral > ISilo(collateralConfig.silo).getLiquidity();
        }
    }

    /// @return receiveCollateralAssets collateral + protected to liquidate, on self liquidation when borrower repay
    /// all debt, he will receive all collateral back
    /// @return repayDebtAssets
    function liquidationPreview( // solhint-disable-line function-max-lines, code-complexity
        SiloSolvencyLib.LtvData memory _ltvData,
        PartialLiquidationLib.LiquidationPreviewParams memory _params
    )
        internal
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets, bytes4 customError)
    {
        uint256 sumOfCollateralAssets = _ltvData.borrowerCollateralAssets + _ltvData.borrowerProtectedAssets;

        if (_ltvData.borrowerDebtAssets == 0 || _params.maxDebtToCover == 0) {
            return (0, 0, IPartialLiquidation.NoDebtToCover.selector);
        }

        if (sumOfCollateralAssets == 0) {
            return (
                0,
                _params.maxDebtToCover > _ltvData.borrowerDebtAssets
                    ? _ltvData.borrowerDebtAssets
                    : _params.maxDebtToCover,
                bytes4(0) // no error
            );
        }

        (
            uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue, uint256 ltvBefore
        ) = SiloSolvencyLib.calculateLtv(_ltvData, _params.collateralConfigAsset, _params.debtConfigAsset);

        if (_params.collateralLt >= ltvBefore) return (0, 0, IPartialLiquidation.UserIsSolvent.selector);

        uint256 ltvAfter;

        (receiveCollateralAssets, repayDebtAssets, ltvAfter) = PartialLiquidationLib.liquidationPreview(
            ltvBefore,
            sumOfCollateralAssets,
            sumOfBorrowerCollateralValue,
            _ltvData.borrowerDebtAssets,
            totalBorrowerDebtValue,
            _params
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) {
            return (0, 0, IPartialLiquidation.NoRepayAssets.selector);
        }
    }
}
