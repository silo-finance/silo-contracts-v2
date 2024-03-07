// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLiquidationLib} from "./SiloLiquidationLib.sol";

library SiloLiquidationExecLib {
    /// @dev that method allow to finish liquidation process by giving up collateral to liquidator
    function withdrawCollateralsToLiquidator(
        ISiloConfig _config,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken,
        uint256 _liquidity,
        mapping(ISilo.AssetType => ISilo.Assets) storage _total
    ) external {
        ISiloConfig.ConfigData memory collateralConfig = _config.getConfig(address(this));
        if (msg.sender != collateralConfig.liquidation) revert ISilo.OnlyLiquidation();

        if (_receiveSToken) {
            withdrawSCollateralToLiquidator(
                collateralConfig.collateralShareToken,
                collateralConfig.protectedShareToken,
                _withdrawAssetsFromCollateral,
                _withdrawAssetsFromProtected,
                _borrower,
                _liquidator,
                _total[ISilo.AssetType.Collateral].assets,
                _total[ISilo.AssetType.Protected].assets
            );
        } else {
            withdrawCollateralToLiquidator(
                collateralConfig,
                _withdrawAssetsFromCollateral,
                _withdrawAssetsFromProtected,
                _borrower,
                _liquidator,
                _liquidity,
                _total
            );
        }
    }

    /// @dev it will be user responsibility to check profit
    function getExactLiquidationAmounts(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _debtToCover,
        uint256 _liquidationFee,
        bool _selfLiquidation
    )
        external

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
            SiloLiquidationLib.LiquidationPreviewParams({
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
        ) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(
            borrowerCollateralToLiquidate, ltvData.borrowerProtectedAssets
        );
    }

    /// @dev debt keeps growing over time, so when dApp use this view to calculate max, tx should never revert
    /// because actual max can be only higher
    function maxLiquidation(
        ISilo _silo,
        address _borrower
    )
        external
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

        return SiloLiquidationLib.maxLiquidation(
            sumOfCollateralAssets,
            sumOfCollateralValue,
            ltvData.borrowerDebtAssets,
            debtValue,
            collateralConfig.lt,
            collateralConfig.liquidationFee
        );
    }

    /// @dev withdraws assets
    function withdrawCollateralToLiquidator(
        ISiloConfig.ConfigData memory _collateralConfig,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        uint256 _liquidity,
        mapping(ISilo.AssetType => ISilo.Assets) storage _total
    ) internal {
        if (_withdrawAssetsFromProtected != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.protectedShareToken,
                _withdrawAssetsFromProtected,
                0, // shares
                _liquidator,
                _borrower,
                _borrower,
                ISilo.AssetType.Protected,
                type(uint256).max,
                _total[ISilo.AssetType.Protected]
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.collateralShareToken,
                _withdrawAssetsFromCollateral,
                0, // shares
                _liquidator,
                _borrower,
                _borrower,
                ISilo.AssetType.Collateral,
                _liquidity,
                _total[ISilo.AssetType.Collateral]
            );
        }
    }

    /// @dev withdraws sTokens
    function withdrawSCollateralToLiquidator(
        address _collateralShareToken,
        address _collateralProtectedShareToken,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        uint256 _totalCollateralAssets,
        uint256 _totalProtectedAssets
    ) internal {
        if (_withdrawAssetsFromProtected != 0) {
            liquidationSTransfer(
                _borrower,
                _liquidator,
                _withdrawAssetsFromProtected,
                _totalProtectedAssets,
                IShareToken(_collateralProtectedShareToken)
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            liquidationSTransfer(
                _borrower,
                _liquidator,
                _withdrawAssetsFromCollateral,
                _totalCollateralAssets,
                IShareToken(_collateralShareToken)
            );
        }
    }

    /// @dev this method expect accrue interest were executed before
    /// it transfer sToken from borrower to liquidator
    function liquidationSTransfer(
        address _borrower,
        address _liquidator,
        uint256 _amountToLiquidate,
        uint256 _totalAssets,
        IShareToken _shareToken
    ) internal {
        // we already accrued interest, so we can work directly on assets
        uint256 shares = SiloMathLib.convertToShares(
            _amountToLiquidate,
            _totalAssets,
            _shareToken.totalSupply(),
            MathUpgradeable.Rounding.Down,
            ISilo.AssetType.Collateral
        );

        _shareToken.forwardTransfer(_borrower, _liquidator, shares);
    }

    /// @return receiveCollateralAssets collateral + protected to liquidate, on self liquidation when borrower repay
    /// all debt, he will receive all collateral back
    /// @return repayDebtAssets
    function liquidationPreview( // solhint-disable-line function-max-lines, code-complexity
        SiloSolvencyLib.LtvData memory _ltvData,
        SiloLiquidationLib.LiquidationPreviewParams memory _params
    )
        internal

        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets)
    {
        uint256 sumOfCollateralAssets;
        // safe because same asset can not overflow
        unchecked  { sumOfCollateralAssets = _ltvData.borrowerCollateralAssets + _ltvData.borrowerProtectedAssets; }

        if (_ltvData.borrowerDebtAssets == 0 || _params.debtToCover == 0) return (0, 0);
        if (sumOfCollateralAssets == 0) return (0, _params.debtToCover);

        (
            uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue, uint256 ltvBefore
        ) = SiloSolvencyLib.calculateLtv(_ltvData, _params.collateralConfigAsset, _params.debtConfigAsset);

        if (_params.selfLiquidation) {
            if (_params.debtToCover >= _ltvData.borrowerDebtAssets) {
                // only because it is self liquidation, we return all collateral on repay all debt
                return (sumOfCollateralAssets, _ltvData.borrowerDebtAssets);
            }
        } else if (_params.collateralLt >= ltvBefore) return (0, 0); // user is solvent

        uint256 ltvAfter;

        (receiveCollateralAssets, repayDebtAssets, ltvAfter) = SiloLiquidationLib.liquidationPreview(
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
