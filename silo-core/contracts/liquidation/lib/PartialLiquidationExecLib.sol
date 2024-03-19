// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "../../lib/SiloSolvencyLib.sol";
import {SiloSolvencyLib2} from "../../lib/SiloSolvencyLib2.sol";
import {PartialLiquidationLib} from "./PartialLiquidationLib.sol";

library PartialLiquidationExecLib {
    /// @dev it will be user responsibility to check profit
    function getExactLiquidationAmounts(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _debtToCover,
        uint256 _liquidationFee,
        bool _selfLiquidation
    )
        internal
        view
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _user,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.No,
            0 /* no cached balance */
        );

        uint256 borrowerCollateralToLiquidate;

        (
            borrowerCollateralToLiquidate, repayDebtAssets
        ) = liquidationPreview(
            ltvData,
            PartialLiquidationLib.LiquidationPreviewParams({
                collateralLt: _collateralConfig.lt,
                collateralConfigAsset: _collateralConfig.token,
                debtConfigAsset: _debtConfig.token,
                debtToCover: _debtToCover,
                liquidationFee: _liquidationFee,
                selfLiquidation: _selfLiquidation
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
    function maxLiquidation(
        ISilo _silo,
        address _borrower
    )
        internal
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        (
            ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig
        ) = _silo.config().getConfigs(address(_silo));

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig,
            debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            0 /* no cached balance */
        );

        if (ltvData.borrowerDebtAssets == 0) return (0, 0);

        (
            uint256 sumOfCollateralValue, uint256 debtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, collateralConfig.token, debtConfig.token);

        uint256 sumOfCollateralAssets;
        // safe because we adding same token, so it is under same total supply
        unchecked { sumOfCollateralAssets = ltvData.borrowerProtectedAssets + ltvData.borrowerCollateralAssets; }

        return PartialLiquidationLib.maxLiquidation(
            sumOfCollateralAssets,
            sumOfCollateralValue,
            ltvData.borrowerDebtAssets,
            debtValue,
            collateralConfig.lt,
            collateralConfig.liquidationFee
        );
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
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets)
    {
        uint256 sumOfCollateralAssets;
        // safe because same asset can not overflow
        unchecked  { sumOfCollateralAssets = _ltvData.borrowerCollateralAssets + _ltvData.borrowerProtectedAssets; }

        if (_ltvData.borrowerDebtAssets == 0 || _params.debtToCover == 0) return (0, 0);
        if (sumOfCollateralAssets == 0) return (0, _params.debtToCover);

        (
            uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue, uint256 ltvBefore
        ) = SiloSolvencyLib2.calculateLtv(_ltvData, _params.collateralConfigAsset, _params.debtConfigAsset);

        if (_params.selfLiquidation) {
            if (_params.debtToCover >= _ltvData.borrowerDebtAssets) {
                // only because it is self liquidation, we return all collateral on repay all debt
                return (sumOfCollateralAssets, _ltvData.borrowerDebtAssets);
            }
        } else if (_params.collateralLt >= ltvBefore) return (0, 0); // user is solvent

        uint256 ltvAfter;

        (receiveCollateralAssets, repayDebtAssets, ltvAfter) = PartialLiquidationLib.liquidationPreview(
            ltvBefore,
            sumOfCollateralAssets,
            sumOfBorrowerCollateralValue,
            _ltvData.borrowerDebtAssets,
            totalBorrowerDebtValue,
            _params
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) return (0, 0);

        if (ltvAfter != 0) { // it can be 0 in case of full liquidation
            if (_params.selfLiquidation) {
                // There is dependency, based on which LTV will be going up and we need to allow for liquidation
                // dependency is: (collateral value / debt value) - 1 > fee
                // when above is true, LTV will go down, otherwise it will always go up.
                // When it will be going up, we are close to bad debt. This "close" depends on how big fee is.
                // Based on that, we can not check if (ltvAfter > ltvBefore), we need to allow for liquidation.
                // In case of self liquidation:
                // - if user is solvent after liquidation, LTV before does not matter
                // - if user was solvent but after liquidation it is not, we need to revert
                // - if user was not solvent, then we need to allow
                if (ltvBefore <= _params.collateralLt && ltvAfter > _params.collateralLt) {
                    revert ISilo.Insolvency();
                }
            }
        }
    }
}
