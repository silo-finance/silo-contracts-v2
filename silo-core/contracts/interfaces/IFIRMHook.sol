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
    function mintSharesAndUpdateSiloState(
        uint256 _debtShares,
        uint256 _collateralShares,
        address _borrower,
        uint256 _interestToDistribute,
        uint256 _interestPayment,
        uint192 _daoAndDeployerRevenue,
        address _firm
    ) external;

    /// @notice Get the maturity date of the FIRM
    /// @return maturityDate
    function maturityDate() external view returns (uint256);

    /// @notice Get the firm address
    /// @return firm address
    function firm() external view returns (address);

    /// @notice Get the firm vault address
    /// @return firmVault address
    function firmVault() external view returns (address);
}
