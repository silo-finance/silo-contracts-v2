// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";

interface IPartialLiquidation {
    struct HookSetup {
        /// @param this is the same as in siloConfig
        address hookReceiver;
        /// @param hooks bitmap
        uint24 hooksBefore;
        /// @param hooks bitmap
        uint24 hooksAfter;
    }

    /// @dev Emitted when a borrower is liquidated.
    /// @param liquidator The address of the liquidator
    /// @param receiveSToken True if the liquidators wants to receive the collateral sTokens, `false` if he wants
    /// to receive the underlying collateral asset directly
    event LiquidationCall(
        address indexed liquidator,
        bool receiveSToken
    );

    error UnexpectedCollateralToken();
    error UnexpectedDebtToken();
    error LiquidityFeeToHi();
    error NoDebtToCover();
    error DebtToCoverTooSmall();
    error OnlyDelegateCall();
    error InvalidSiloForCollateral();
    error UserIsSolvent();
    error InsufficientLiquidation();
    error LiquidationTooBig();
    error WrongSilo();
    error UnknownRatio();

    /// @notice Function to liquidate a non-healthy debt collateral-wise
    /// - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
    ///   a amount of the `collateralAsset` plus a bonus to cover market risk
    /// @dev user can use this method to do self liquidation, it that case, check for LT requirements will be ignored
    /// @param _siloWithDebt The address of the silo where the debt it
    /// @param _collateralAsset The address of the underlying asset used as collateral, to receive as result
    /// @param _debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
    /// @param _user The address of the borrower getting liquidated
    /// @param _debtToCover The debt amount of borrowed `asset` the liquidator wants to cover,
    /// in case this amount is too big, it will be reduced to maximum allowed liquidation amount
    /// @param _receiveSToken True if the liquidators wants to receive the collateral sTokens, `false` if he wants
    /// to receive the underlying collateral asset directly
    /// @return withdrawCollateral collateral that was send to `msg.sender`
    /// @return repayDebtAssets actual debt value that was repayed by `msg.sender`
    function liquidationCall(
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _user,
        uint256 _debtToCover,
        bool _receiveSToken
    )
        external
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets);

    /// @dev Repays a given asset amount and returns the equivalent number of shares
    /// @notice this repay is only for liquidation, because it must be called as delegate call from Silo
    /// @param _assets Amount of assets to be repaid
    /// @param _borrower Address of the borrower whose debt is being repaid
    /// @param _repayer Address of the wallet which will repay debt
    /// @return shares The equivalent number of shares for the provided asset amount
    function liquidationRepay(uint256 _assets, address _borrower, address _repayer) external returns (uint256 shares);

    /// @dev this is only for liquidation, should be called as delegate call
    /// copy of `_withdraw` from Silo
    function liquidationWithdraw(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        ISilo.CollateralType _collateralType
    )
        external
        returns (uint256 assets, uint256 shares);

    /// @dev that method allow to finish liquidation process by giving up collateral to liquidator
    /// @notice this withdraw is only for liquidation, because it must be called as delegate call from Silo
    function withdrawCollateralsToLiquidator(
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken
    ) external;

    /// @dev debt is keep growing over time, so when dApp use this view to calculate max, tx should never revert
    /// because actual max can be only higher
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay);
}
