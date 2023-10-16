// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

// solhint-disable function-max-lines

library SiloERC4626Lib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @dev ERC4626: MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be
    ///      deposited.
    uint256 internal constant _NO_DEPOSIT_LIMIT = type(uint256).max - 1;

    function maxDepositOrMint(ISiloConfig _config, address _receiver)
        external
        view
        returns (uint256 maxAssetsOrShares)
    {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        if (depositPossible(configData.debtShareToken, _receiver)) {
            maxAssetsOrShares = _NO_DEPOSIT_LIMIT;
        }
    }

    /// @param _liquidity available liquidity in Silo
    /// @param _totalAssets based on `_assetType` this is total collateral/protected assets
    function maxWithdraw(
        ISiloConfig _config,
        address _owner,
        ISilo.AssetType _assetType,
        uint256 _totalAssets,
        uint256 _liquidity
    ) external view returns (uint256 assets, uint256 shares) {
        if (_assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = _config.getConfigs(address(this));

        uint256 shareTokenTotalSupply = _assetType == ISilo.AssetType.Collateral
            ? IShareToken(collateralConfig.collateralShareToken).totalSupply()
            : IShareToken(collateralConfig.protectedShareToken).totalSupply();

        if (!hasDebt(debtConfig.debtShareToken, _owner)) {
            shares = _assetType == ISilo.AssetType.Collateral
                ? IShareToken(collateralConfig.collateralShareToken).balanceOf(_owner)
                : IShareToken(collateralConfig.protectedShareToken).balanceOf(_owner);

            assets = SiloMathLib.convertToAssets(
                shares,
                _totalAssets,
                shareTokenTotalSupply,
                MathUpgradeable.Rounding.Down,
                _assetType
            );

            return (assets, shares);
        }

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig, debtConfig, _owner, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.Yes
        );

        (uint256 collateralValue, uint256 debtValue) =
            SiloSolvencyLib.getPositionValues(ltvData, collateralConfig.token, debtConfig.token);

        assets = SiloMathLib.calculateMaxAssetsToWithdraw(
            collateralValue,
            debtValue,
            collateralConfig.lt,
            ltvData.borrowerProtectedAssets,
            ltvData.borrowerCollateralAssets
        );

        return SiloMathLib.maxWithdrawToAssetsAndShares(
            assets,
            ltvData.borrowerCollateralAssets,
            ltvData.borrowerProtectedAssets,
            _assetType,
            _totalAssets,
            shareTokenTotalSupply,
            _liquidity
        );
    }

    /// @param _token if empty, tokens will not be transferred, useful for transition of collateral
    function deposit(
        address _token,
        address _depositor,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        IShareToken _collateralShareToken,
        IShareToken _debtShareToken,
        ISilo.Assets storage _totalCollateral
    ) public returns (uint256 assets, uint256 shares) {
        if (_depositParams.assets > type(uint128).max) revert ISilo.Overflow();

        if (!depositPossible(address(_debtShareToken), _receiver)) {
            revert ISilo.DepositNotPossible();
        }

        uint256 totalAssets = _totalCollateral.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalAssets,
            _collateralShareToken.totalSupply(),
            MathUpgradeable.Rounding.Up,
            MathUpgradeable.Rounding.Down,
            ISilo.AssetType.Collateral
        );

        if (_token != address(0)) {
            // Transfer tokens before minting. No state changes have been made so reentrancy does nothing
            IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);
        }

        // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
        unchecked {
            _totalCollateral.assets = totalAssets + assets;
        }

        // Hook receiver is called after `mint` and can reentry but state changes are completed already
        _collateralShareToken.mint(_receiver, _depositor, shares);
    }

    /// this helped with stack too deep
    function transitionCollateralWithdraw(
        address _shareToken,
        uint256 _shares,
        address _owner,
        address _spender,
        ISilo.AssetType _assetType,
        uint256 _liquidity,
        ISilo.Assets storage _totalCollateral
    ) public returns (uint256 assets, uint256 shares) {
        return withdraw(
            address(0), _shareToken, 0, _shares, _owner, _owner, _spender, _assetType, _liquidity, _totalCollateral
        );
    }

    /// @notice asset type is not verified here, make sure you revert before, when type == Debt
    /// @param _asset token address that we want to withdraw, if empty, withdraw action will be done WITHOUT
    /// actual token transfer
    /// @param _assets amount of assets to withdraw, if 0, means withdraw is based on `shares`
    /// @param _shares depends on `assets` it can be 0 or not
    function withdraw(
        address _asset,
        address _shareToken,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        ISilo.AssetType _assetType,
        uint256 _liquidity,
        ISilo.Assets storage _totalCollateral
    ) public returns (uint256 assets, uint256 shares) {
        if (_params.assets > type(uint128).max) revert ISilo.Overflow();

        uint256 totalAssets = _totalCollateral.assets;

        uint256 shareTotalSupply = IShareToken(_shareToken).totalSupply();
        if (shareTotalSupply == 0) revert ISilo.NothingToWithdraw();

        { // Stack too deep
            uint256 totalAssets = _totalCollateral.assets;

            (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
                _assets,
                _shares,
                totalAssets,
                shareTotalSupply,
                MathUpgradeable.Rounding.Down,
                MathUpgradeable.Rounding.Up,
                _assetType
            );

            if (assets == 0 || shares == 0) revert ISilo.NothingToWithdraw();

            // check liquidity
            if (assets > _liquidity) revert ISilo.NotEnoughLiquidity();

            // `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            // `assets` and interest
            unchecked { _totalCollateral.assets = totalAssets - assets; }
        }

        // `burn` checks if `_spender` is allowed to withdraw `_owner` assets. `burn` calls hook receiver that
        // can potentially reenter but state changes are already completed.
        IShareToken(_shareToken).burn(_owner, _spender, shares);

        if (_asset != address(0)) {
            // fee-on-transfer is ignored
            IERC20Upgradeable(_asset).safeTransfer(_receiver, assets);
        }
    }

    function depositPossible(address _debtShareToken, address _depositor) public view returns (bool) {
        return IShareToken(_debtShareToken).balanceOf(_depositor) == 0;
    }

    function hasDebt(address _debtShareToken, address _owner) internal view returns (bool debt) {
        debt = IShareToken(_debtShareToken).balanceOf(_owner) != 0;
    }
}
