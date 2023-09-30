// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

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

    /// @param assets amount of assets to withdraw, if 0, means withdraw is based on `shares`
    /// @param shares depends on `assets` it can be 0 or not
    struct WithdrawParams {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        ISilo.AssetType assetType;
    }

    struct DepositParams {
        uint256 assets;
        uint256 shares;
        address receiver;
        ISilo.AssetType assetType;
        IShareToken collateralShareToken;
        IShareToken debtShareToken;
    }

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
        {
            bool isVault;

            (assets, shares, isVault) = maxWithdrawForVaults(_config, _owner, _totalAssets, _assetType);

            if (isVault) {
                return (assets, shares);
            }
        }

        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) =
            _config.getConfigs(address(this));

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

        uint256 shareTokenTotalSupply = _assetType == ISilo.AssetType.Protected
            ? IShareToken(collateralConfig.protectedShareToken).totalSupply()
            : IShareToken(collateralConfig.collateralShareToken).totalSupply();

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

    /// @param _asset if empty, tokens will not be transferred, useful for transition of collateral
    function deposit(
        address _asset,
        address _depositor,
        DepositParams memory _depositParams,
        ISilo.Assets storage _totalCollateral
    ) public returns (uint256 assets, uint256 shares) {
        if (!depositPossible(address(_depositParams.debtShareToken), _depositParams.receiver)) {
            revert ISilo.DepositNotPossible();
        }

        uint256 totalAssets = _totalCollateral.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _depositParams.assets,
            _depositParams.shares,
            totalAssets,
            _depositParams.collateralShareToken.totalSupply(),
            MathUpgradeable.Rounding.Up,
            MathUpgradeable.Rounding.Down,
            ISilo.AssetType.Collateral
        );

        if (_asset != address(0)) {
            // Transfer tokens before minting. No state changes have been made so reentrancy does nothing
            IERC20Upgradeable(_asset).safeTransferFrom(_depositor, address(this), assets);
        }

        // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
        unchecked {
            _totalCollateral.assets = totalAssets + assets;
        }

        // Hook receiver is called after `mint` and can reentry but state changes are completed already
        _depositParams.collateralShareToken.mint(_depositParams.receiver, _depositor, shares);
    }

    /// @notice asset type is not verified here, make sure you revert before, when type == Debt
    /// @param _asset token address that we want to withdraw, if empty, withdraw action will be done WITHOUT
    /// actual token transfer
    function withdraw(
        address _asset,
        address _shareToken,
        WithdrawParams memory _params,
        uint256 _liquidity,
        ISilo.Assets storage _totalCollateral
    ) public returns (uint256 assets, uint256 shares) {
        uint256 totalAssets = _totalCollateral.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _params.assets,
            _params.shares,
            totalAssets,
            IShareToken(_shareToken).totalSupply(),
            MathUpgradeable.Rounding.Down,
            MathUpgradeable.Rounding.Up,
            ISilo.AssetType.Collateral
        );

        if (assets == 0 || shares == 0) revert ISilo.NothingToWithdraw();

        // check liquidity
        if (assets > _liquidity) revert ISilo.NotEnoughLiquidity();

        // `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
        // `assets` and interest
        unchecked {
            _totalCollateral.assets = totalAssets - assets;
        }

        // `burn` checks if `_spender` is allowed to withdraw `_owner` assets. `burn` calls hook receiver that
        // can potentially reenter but state changes are already completed.
        IShareToken(_shareToken).burn(_params.owner, _params.spender, shares);

        if (_asset != address(0)) {
            // fee-on-transfer is ignored
            IERC20Upgradeable(_asset).safeTransferFrom(address(this), _params.receiver, assets);
        }
    }

    function depositPossible(address _debtShareToken, address _depositor) public view returns (bool) {
        return IShareToken(_debtShareToken).balanceOf(_depositor) == 0;
    }

    /// @notice maxWithdraw optimized implemencation for vaults that only use collateral and do not have debt
    function maxWithdrawForVaults(
        ISiloConfig _config,
        address _owner,
        uint256 _totalAssets,
        ISilo.AssetType _assetType
    ) internal view returns (uint256 assets, uint256 shares, bool isVault) {
        if (_assetType == ISilo.AssetType.Collateral) {
            (, address collateralShareToken, address debtShareToken) = _config.getShareTokens(address(this));

            if (IShareToken(debtShareToken).balanceOf(_owner) == 0) {
                shares = IShareToken(collateralShareToken).balanceOf(_owner);
                assets = SiloMathLib.convertToAssets(
                    shares,
                    _totalAssets,
                    IShareToken(collateralShareToken).totalSupply(),
                    MathUpgradeable.Rounding.Down,
                    _assetType
                );

                return (assets, shares, true);
            }
        }
    }
}
