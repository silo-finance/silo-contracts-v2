// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {Rounding} from "./Rounding.sol";
import {Hook} from "./Hook.sol";

// solhint-disable function-max-lines

library SiloERC4626Lib {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @dev ERC4626: MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be
    ///      deposited. In our case, we want to limit this value in a way, that after max deposit we can do borrow.
    ///      That's why we decided to go with type(uint128).max - which is anyway high enough to consume any totalSupply
    uint256 internal constant _VIRTUAL_DEPOSIT_LIMIT = type(uint128).max;

    /// @notice Determines the maximum amount of collateral a user can deposit
    /// This function is estimation to reduce gas usage. In theory, if silo total assets will be close to virtual limit
    /// and returned max assets will be eg 1, then it might be not possible to actually deposit 1wei because
    /// tx will revert with ZeroShares error. This is unreal case in real world scenario so we ignoring it.
    /// @dev The function checks, if deposit is possible for the given user, and if so, returns a constant
    /// representing no deposit limit
    /// @param _totalCollateralAssets total deposited collateral
    /// @return maxAssetsOrShares Maximum assets/shares a user can deposit
    function maxDepositOrMint(uint256 _totalCollateralAssets)
        internal
        pure
        returns (uint256 maxAssetsOrShares)
    {
        // safe to unchecked because we checking manually to prevent revert
        unchecked {
            maxAssetsOrShares = _totalCollateralAssets == 0
                ? _VIRTUAL_DEPOSIT_LIMIT
                : (_totalCollateralAssets >= _VIRTUAL_DEPOSIT_LIMIT)
                        ? 0
                        : _VIRTUAL_DEPOSIT_LIMIT - _totalCollateralAssets;
        }
    }

    /// @notice Determines the maximum amount a user can withdraw, either in terms of assets or shares
    /// @dev The function computes the maximum withdrawable assets and shares, considering user's collateral, debt,
    /// and the liquidity in the silo.
    /// Debt withdrawals are not allowed, resulting in a revert if such an attempt is made.
    /// @param _config Configuration of the silo
    /// @param _owner Address of the user for which the maximum withdrawal amount is calculated
    /// @param _collateralType The type of asset being considered for withdrawal
    /// @param _totalAssets The total PROTECTED assets in the silo. In case of collateral use `0`, total
    /// collateral will be calculated internally with interest
    /// @return assets The maximum assets that the user can withdraw
    /// @return shares The maximum shares that the user can withdraw
    function maxWithdraw(
        ISiloConfig _config,
        address _owner,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets
    ) internal view returns (uint256 assets, uint256 shares) {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _config.getConfigs(address(this), _owner, Hook.WITHDRAW);

        uint256 shareTokenTotalSupply;
        uint256 liquidity;

        if (_collateralType == ISilo.CollateralType.Collateral) {
            shareTokenTotalSupply = IShareToken(collateralConfig.collateralShareToken).totalSupply();
            (liquidity, _totalAssets, ) = SiloLendingLib.getLiquidityAndAssetsWithInterest(collateralConfig);
        } else {
            shareTokenTotalSupply = IShareToken(collateralConfig.protectedShareToken).totalSupply();
            liquidity = _totalAssets;
        }

        if (SiloSolvencyLib.depositWithoutDebt(debtInfo)) {
            shares = _collateralType == ISilo.CollateralType.Protected
                ? IShareToken(collateralConfig.protectedShareToken).balanceOf(_owner)
                : IShareToken(collateralConfig.collateralShareToken).balanceOf(_owner);

            assets = SiloMathLib.convertToAssets(
                shares,
                _totalAssets,
                shareTokenTotalSupply,
                Rounding.MAX_WITHDRAW_TO_ASSETS,
                ISilo.AssetType(uint256(_collateralType))
            );

            if (_collateralType == ISilo.CollateralType.Protected || assets <= liquidity) return (assets, shares);

            assets = liquidity;

            shares = SiloMathLib.convertToShares(
                assets,
                _totalAssets,
                shareTokenTotalSupply,
                // when we doing withdraw, we using Rounding.Ceil, because we want to burn as many shares
                // however here, we will be using shares as input to withdraw, if we round up, we can overflow
                // because we will want to withdraw too much, so we have to use Rounding.Floor
                Rounding.MAX_WITHDRAW_TO_SHARES,
                ISilo.AssetType.Collateral
            );

            return (assets, shares);
        } else {
            return maxWithdrawWhenDebt(
                collateralConfig, debtConfig, _owner, liquidity, shareTokenTotalSupply, _collateralType, _totalAssets
            );
        }
    }

    function maxWithdrawWhenDebt(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _owner,
        uint256 _liquidity,
        uint256 _shareTokenTotalSupply,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets
    ) internal view returns (uint256 assets, uint256 shares) {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _owner,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            IShareToken(_debtConfig.debtShareToken).balanceOf(_owner)
        );

        {
            (uint256 collateralValue, uint256 debtValue) =
                SiloSolvencyLib.getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);

            assets = SiloMathLib.calculateMaxAssetsToWithdraw(
                collateralValue,
                debtValue,
                _collateralConfig.lt,
                ltvData.borrowerProtectedAssets,
                ltvData.borrowerCollateralAssets
            );
        }

        (assets, shares) = SiloMathLib.maxWithdrawToAssetsAndShares(
            assets,
            ltvData.borrowerCollateralAssets,
            ltvData.borrowerProtectedAssets,
            _collateralType,
            _totalAssets,
            _shareTokenTotalSupply,
            _liquidity
        );

        if (assets != 0) {
            // even if we using rounding Down, we still need underestimation with 1wei
            unchecked { assets--; }
        }
    }

    /// this helped with stack too deep
    function transitionCollateralWithdraw(
        address _shareToken,
        uint256 _shares,
        address _owner,
        address _spender,
        ISilo.CollateralType _collateralType,
        uint256 _liquidity,
        ISilo.Assets storage _totalCollateral
    ) internal returns (uint256 assets, uint256 shares) {
        return withdraw(
            address(0),
            _shareToken,
            ISilo.WithdrawArgs({
                assets: 0,
                shares: _shares,
                owner: _owner,
                receiver: _owner,
                spender: _spender,
                collateralType: _collateralType
            }),
            _liquidity,
            _totalCollateral
        );
    }

    /// @notice Deposit assets into the silo
    /// @param _token The ERC20 token address being deposited; 0 means tokens will not be transferred. Useful for
    /// transition of collateral.
    /// @param _depositor Address of the user depositing the assets
    /// @param _assets Amount of assets being deposited. Use 0 if shares are provided.
    /// @param _shares Shares being exchanged for the deposit; used for precise calculations. Use 0 if assets are
    /// provided.
    /// @param _receiver The address that will receive the collateral shares
    /// @param _collateralShareToken The collateral share token
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
        ISilo.Assets storage _totalCollateral
    ) internal returns (uint256 assets, uint256 shares) {
        uint256 totalAssets = _totalCollateral.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalAssets,
            _collateralShareToken.totalSupply(),
            Rounding.DEPOSIT_TO_ASSETS,
            Rounding.DEPOSIT_TO_SHARES,
            ISilo.AssetType.Collateral
        );

        if (assets == 0) revert ISilo.ZeroAssets();
        if (shares == 0) revert ISilo.ZeroShares();

        // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
        // however, there is (probably unreal but also untested) possibility, where you might borrow from silo
        // and deposit (like double spend) and with that we could overflow. Better safe than sorry - unchecked removed
        // unchecked {
        _totalCollateral.assets = totalAssets + assets;
        // }

        // Hook receiver is called after `mint` and can reentry but state changes are completed already
        _collateralShareToken.mint(_receiver, _depositor, shares);

        if (_token != address(0)) {
            // Reentrancy is possible only for view methods (read-only reentrancy),
            // so no harm can be done as the state is already updated.
            // We do not expect the silo to work with any malicious token that will not send tokens to silo.
            IERC20(_token).safeTransferFrom(_depositor, address(this), assets);
        }
    }

    /// @notice Withdraw assets from the silo
    /// @dev Asset type is not verified here, make sure you revert before when type == Debt
    /// @param _asset The ERC20 token address to withdraw; 0 means tokens will not be transferred. Useful for
    /// transition of collateral.
    /// @param _shareToken Address of the share token being burned for withdrawal
    /// @param _args ISilo.WithdrawArgs
    /// @param _liquidity Available liquidity for the withdrawal
    /// @param _totalCollateral Reference to the total collateral assets in the silo
    /// @return assets The exact amount of assets withdrawn
    /// @return shares The exact number of shares burned in exchange for the withdrawn assets
    function withdraw(
        address _asset,
        address _shareToken,
        ISilo.WithdrawArgs memory _args,
        uint256 _liquidity,
        ISilo.Assets storage _totalCollateral
    ) internal returns (uint256 assets, uint256 shares) {
        uint256 shareTotalSupply = IShareToken(_shareToken).totalSupply();
        if (shareTotalSupply == 0) revert ISilo.NothingToWithdraw();

        { // Stack too deep
            uint256 totalAssets = _totalCollateral.assets;

            (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
                _args.assets,
                _args.shares,
                totalAssets,
                shareTotalSupply,
                Rounding.WITHDRAW_TO_ASSETS,
                Rounding.WITHDRAW_TO_SHARES,
                ISilo.AssetType(uint256(_args.collateralType))
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
        IShareToken(_shareToken).burn(_args.owner, _args.spender, shares);

        if (_asset != address(0)) {
            // fee-on-transfer is ignored
            IERC20(_asset).safeTransfer(_args.receiver, assets);
        }
    }
}
