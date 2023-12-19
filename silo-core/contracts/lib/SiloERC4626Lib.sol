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
import {SiloStdLib} from "./SiloStdLib.sol";

// solhint-disable function-max-lines

library SiloERC4626Lib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @dev ERC4626: MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be
    ///      deposited.
    uint256 internal constant _NO_DEPOSIT_LIMIT = type(uint256).max;

    error ZeroShares();

    /// @notice Determines the maximum amount a user can deposit or mint
    /// @dev The function checks if deposit is possible for the given user, and if so, returns a constant
    /// representing no deposit limit
    /// @param _config Configuration of the silo
    /// @param _receiver The address of the user
    /// @return maxAssetsOrShares Maximum assets or shares a user can deposit or mint
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

    /// @notice Determines the maximum amount a user can withdraw, either in terms of assets or shares
    /// @dev The function computes the maximum withdrawable assets and shares, considering user's collateral, debt,
    /// and the liquidity in the silo.
    /// Debt withdrawals are not allowed, resulting in a revert if such an attempt is made.
    /// @param _config Configuration of the silo
    /// @param _owner Address of the user for which the maximum withdrawal amount is calculated
    /// @param _assetType The type of asset being considered for withdrawal
    /// @param _totalAssets The total assets in the silo. Can be collateral or protected depending on `_assetType`.
    /// @param _liquidity The available liquidity in the silo
    /// @return assets The maximum assets that the user can withdraw
    /// @return shares The maximum shares that the user can withdraw
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

        if (_assetType == ISilo.AssetType.Collateral) {
            _totalAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
                address(this),
                collateralConfig.interestRateModel,
                collateralConfig.daoFee,
                collateralConfig.deployerFee
            );
        }

        uint256 shareTokenTotalSupply = _assetType == ISilo.AssetType.Collateral
            ? IShareToken(collateralConfig.collateralShareToken).totalSupply()
            : IShareToken(collateralConfig.protectedShareToken).totalSupply();

        SiloSolvencyLib.LtvData memory ltvData;

        { // stack too deep
            uint256 debt = IShareToken(debtConfig.debtShareToken).balanceOf(_owner);

            if (debt == 0) {
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

                if (assets > _liquidity) {
                    assets = _liquidity;

                    shares = SiloMathLib.convertToShares(
                        assets,
                        _totalAssets,
                        shareTokenTotalSupply,
                        MathUpgradeable.Rounding.Up,
                        _assetType
                    );
                }

                return (assets, shares);
            }

            ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
                collateralConfig, debtConfig, _owner, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.Yes, debt
            );
        }

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

    /// @notice Deposit assets into the silo
    /// @dev Deposits are not allowed if the receiver already has some debt
    /// @param _token The ERC20 token address being deposited; 0 means tokens will not be transferred. Useful for
    /// transition of collateral.
    /// @param _depositor Address of the user depositing the assets
    /// @param _assets Amount of assets being deposited. Use 0 if shares are provided.
    /// @param _shares Shares being exchanged for the deposit; used for precise calculations. Use 0 if assets are
    /// provided.
    /// @param _receiver The address that will receive the collateral shares
    /// @param _collateralShareToken The collateral share token
    /// @param _debtShareToken The debt share token
    /// @param _totalCollateral Reference to the total collateral assets in the silo
    /// @return assets The exact amount of assets being deposited
    /// @return shares The exact number of collateral shares being minted in exchange for the deposited assets
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

        if (shares == 0) revert ZeroShares();

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

    /// @notice Withdraw assets from the silo
    /// @dev Asset type is not verified here, make sure you revert before when type == Debt
    /// @param _asset The ERC20 token address to withdraw; 0 means tokens will not be transferred. Useful for
    /// transition of collateral.
    /// @param _shareToken Address of the share token being burned for withdrawal
    /// @param _assets Amount of assets the user wishes to withdraw. Use 0 if shares are provided.
    /// @param _shares Shares the user wishes to burn in exchange for the withdrawal. Use 0 if assets are provided.
    /// @param _receiver Address receiving the withdrawn assets
    /// @param _owner Address of the owner of the shares being burned
    /// @param _spender Address executing the withdrawal; may be different than `_owner` if an allowance was set
    /// @param _assetType Type of the asset being withdrawn (Collateral or Protected)
    /// @param _liquidity Available liquidity for the withdrawal
    /// @param _totalCollateral Reference to the total collateral assets in the silo
    /// @return assets The exact amount of assets withdrawn
    /// @return shares The exact number of shares burned in exchange for the withdrawn assets
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

    /// @notice Checks if a depositor can make a deposit
    /// @param _debtShareToken Address of the debt share token
    /// @param _depositor Address of the user attempting to deposit
    /// @return Returns `true` if the depositor can deposit, otherwise `false`
    function depositPossible(address _debtShareToken, address _depositor) public view returns (bool) {
        return IShareToken(_debtShareToken).balanceOf(_depositor) == 0;
    }
}
