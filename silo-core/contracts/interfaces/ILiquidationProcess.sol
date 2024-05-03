// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

// solhint-disable ordering
interface ILiquidationProcess {
    /// @dev Repays a given asset amount and returns the equivalent number of shares
    /// @notice this repay is only for liquidation because `_repayer` is passed as argument
    /// if we leave it open, anyone can exeute repay for someone who gives allowance to silo
    /// @param _assets Amount of assets to be repaid
    /// @param _borrower Address of the borrower whose debt is being repaid
    /// @param _repayer Address of the wallet which will repay debt
    /// @return shares The equivalent number of shares for the provided asset amount
    function liquidationRepay(uint256 _assets, address _borrower, address _repayer) external returns (uint256 shares);

    function withdrawCollateralsToLiquidator(
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken
    ) external;
}
