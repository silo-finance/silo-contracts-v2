// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IFIRMHook {
    error BorrowSameAssetNotAllowed();
    error OnlyFirmVaultCanDeposit();
    error OnlyFIRMVaultOrFirmCanReceiveCollateral();
    error InvalidMaturityDate();
    error EmptyFirmVault();
    error MaturityDateReached();

    /// @dev Mint shares and update Silo state
    /// This function is designed to be called by the hook from the silo via delegatecall.
    /// @param _debtShares amount of debt shares to mint
    /// @param _collateralShares amount of collateral shares to mint
    /// @param _borrower address of the borrower
    /// @param _interestToDistribute amount of interest to distribute
    /// @param _interestPayment amount of interest payment
    /// @param _daoAndDeployerRevenue amount of dao and deployer revenue
    /// @param _firm address of the firm
    function siloTakesBorrowFeeUpfront(
        uint256 _debtShares,
        uint256 _collateralShares,
        address _borrower,
        uint256 _interestToDistribute,
        uint256 _interestPayment,
        uint192 _daoAndDeployerRevenue,
        address _firm
    ) external;

    /// @notice Get the maturity date of the fixed IRM
    function maturityDate() external view returns (uint256 maturity);

    /// @notice Get the fixed IRM address
    function firm() external view returns (address firmAddress);

    /// @notice Get the fixed IRM vault address
    function firmVault() external view returns (address firmVaultAddress);
}
