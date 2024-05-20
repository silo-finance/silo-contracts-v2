// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {Rounding} from "./Rounding.sol";
import {AssetTypes} from "./AssetTypes.sol";
import {Hook} from "./Hook.sol";

library LiquidationWithdrawLib {
    /// @dev that method allow to finish liquidation process by giving up collateral to liquidator
    function withdrawCollateralsToLiquidator(
        ISiloConfig _config,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken,
        uint256 _liquidity,
        mapping(uint256 assetType => ISilo.Assets) storage _total
    ) internal {
        ISiloConfig.ConfigData memory collateralConfig = _config.getConfig(address(this));
        if (msg.sender != collateralConfig.liquidationModule) revert ISilo.OnlyLiquidationModule();

        if (_receiveSToken) {
            withdrawSCollateralToLiquidator(
                collateralConfig.collateralShareToken,
                collateralConfig.protectedShareToken,
                _withdrawAssetsFromCollateral,
                _withdrawAssetsFromProtected,
                _borrower,
                _liquidator,
                _total[AssetTypes.COLLATERAL].assets,
                _total[AssetTypes.PROTECTED].assets
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
        mapping(uint256 assetType => ISilo.Assets) storage _total
    ) internal {
        if (_withdrawAssetsFromProtected != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.protectedShareToken,
                ISilo.WithdrawArgs({
                    assets: _withdrawAssetsFromProtected,
                    shares: 0,
                    receiver: _liquidator,
                    owner: _borrower,
                    spender: _borrower,
                    collateralType: ISilo.CollateralType.Protected
                }),
                _total[AssetTypes.PROTECTED].assets,
                _total[AssetTypes.PROTECTED]
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.collateralShareToken,
                ISilo.WithdrawArgs({
                    assets: _withdrawAssetsFromCollateral,
                    shares: 0,
                    receiver: _liquidator,
                    owner: _borrower,
                    spender: _borrower,
                    collateralType: ISilo.CollateralType.Collateral
                }),
                _liquidity,
                _total[AssetTypes.COLLATERAL]
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
                IShareToken(_collateralProtectedShareToken),
                ISilo.AssetType.Protected
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            liquidationSTransfer(
                _borrower,
                _liquidator,
                _withdrawAssetsFromCollateral,
                _totalCollateralAssets,
                IShareToken(_collateralShareToken),
                ISilo.AssetType.Collateral
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
        IShareToken _shareToken,
        ISilo.AssetType _assetType
    ) internal {
        // we already accrued interest, so we can work directly on assets
        uint256 shares = SiloMathLib.convertToShares(
            _amountToLiquidate,
            _totalAssets,
            _shareToken.totalSupply(),
            Rounding.LIQUIDATE_TO_SHARES,
            _assetType
        );

        _shareToken.forwardTransfer(_borrower, _liquidator, shares);
    }
}
