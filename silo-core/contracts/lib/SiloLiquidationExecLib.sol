// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloLiquidation} from "../interfaces/ISiloLiquidation.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLiquidationLib} from "./SiloLiquidationLib.sol";

library SiloLiquidationExecLib {
    uint256 internal constant _BASIS_POINTS = 1e4;

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
    ) internal {
        ISiloConfig.ConfigData memory collateralConfig = _config.getConfig(address(this));
        if (msg.sender != collateralConfig.otherSilo) revert ISiloLiquidation.OnlySilo();

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
                SiloERC4626Lib.WithdrawParams({
                    assets: _withdrawAssetsFromProtected,
                    shares: 0,
                    receiver: _liquidator,
                    owner: _borrower,
                    spender: _borrower,
                    assetType: ISilo.AssetType.Protected
                }),
                type(uint256).max,
                _total[ISilo.AssetType.Protected]
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.collateralShareToken,
                SiloERC4626Lib.WithdrawParams({
                    assets: _withdrawAssetsFromCollateral,
                    shares: 0,
                    receiver: _liquidator,
                    owner: _borrower,
                    spender: _borrower,
                    assetType: ISilo.AssetType.Collateral
                }),
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
                _totalCollateralAssets,
                IShareToken(_collateralProtectedShareToken)
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            liquidationSTransfer(
                _borrower,
                _liquidator,
                _withdrawAssetsFromCollateral,
                _totalProtectedAssets,
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
            _amountToLiquidate, _totalAssets, _shareToken.totalSupply(), MathUpgradeable.Rounding.Down
        );

        _shareToken.liquidationTransfer(_borrower, _liquidator, shares);
    }

    /// @dev it will be user responsibility to check profit
    function getExactLiquidationAmounts(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _debtToCover,
        uint256 _liquidationFeeInBp,
        bool _selfLiquidation
    )
        internal
        view
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig, _debtConfig, _user, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.No
        );

        uint256 borrowerCollateralToLiquidate;

        (
            borrowerCollateralToLiquidate, repayDebtAssets
        ) = liquidationPreview(
            ltvData,
            _collateralConfig.lt,
            _collateralConfig.token,
            _debtConfig.token,
            _debtToCover,
            _liquidationFeeInBp,
            _selfLiquidation
        );

        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected
        ) = SiloMathLib.splitReceiveCollateralToLiquidate(borrowerCollateralToLiquidate, ltvData.protectedAssets);
    }

    /// @return receiveCollateralAssets collateral + protected to liquidate
    /// @return repayDebtAssets
    function liquidationPreview(
        SiloSolvencyLib.LtvData memory _ltvData,
        uint256 _collateralLt,
        address _collateralConfigToken,
        address _debtConfigToken,
        uint256 _debtToCover,
        uint256 _liquidationFeeInBp,
        bool _selfLiquidation
    )
        internal
        view
        returns (
            uint256 receiveCollateralAssets,
            uint256 repayDebtAssets
        )
    {
        uint256 totalCollateralAssets = _ltvData.collateralAssets + _ltvData.protectedAssets;

        if (_ltvData.debtAssets == 0 || totalCollateralAssets == 0) revert ISiloLiquidation.UserIsSolvent();

        (
            uint256 ltvInBp, uint256 totalBorrowerDebtValue, uint256 totalBorrowerCollateralValue
        ) = SiloSolvencyLib.calculateLtv(_ltvData, _collateralConfigToken, _debtConfigToken);

        if (!_selfLiquidation && _collateralLt > ltvInBp) revert ISiloLiquidation.UserIsSolvent();

        // TODO do not do full liquidation, do partial
        if (ltvInBp >= _BASIS_POINTS) { // in case of bad debt we return all
            return (totalCollateralAssets, _ltvData.debtAssets);
        }

        (receiveCollateralAssets, repayDebtAssets, ltvInBp) = SiloLiquidationLib.calculateExactLiquidationAmounts(
            _debtToCover,
            totalBorrowerDebtValue,
            _ltvData.debtAssets,
            totalBorrowerCollateralValue,
            totalCollateralAssets,
            _liquidationFeeInBp
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) revert ISiloLiquidation.UserIsSolvent();

        if (ltvInBp != 0) { // it can be 0 in case of full liquidation
            if (!_selfLiquidation && ltvInBp < SiloLiquidationLib.minAcceptableLT(_collateralLt)) {
                revert ISiloLiquidation.LiquidationTooBig();
            }
        }
    }
}
