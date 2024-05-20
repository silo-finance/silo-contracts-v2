// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";

interface ISiloLens {
    /// @notice Checks if borrowing is possible for a given borrower
    /// @param _silo Address of the silo
    /// @param _borrower Address of the borrower to check for borrowing possibility
    /// @return True if borrowing is possible for the borrower, otherwise false
    function borrowPossible(ISilo _silo, address _borrower) external view returns (bool);

    /// @notice Retrieves the maximum loan-to-value (LTV) ratio
    /// @param _silo Address of the silo
    /// @return maxLtv The maximum LTV ratio configured for the silo in 18 decimals points
    function getMaxLtv(ISilo _silo) external view returns (uint256 maxLtv);

    /// @notice Retrieves the LT value
    /// @param _silo Address of the silo
    /// @return lt The LT value in 18 decimals points
    function getLt(ISilo _silo) external view returns (uint256 lt);

    /// @notice Retrieves the loan-to-value (LTV) for a specific borrower
    /// @param _silo Address of the silo
    /// @param _borrower Address of the borrower
    /// @return ltv The LTV for the borrower in 18 decimals points
    function getLtv(ISilo _silo, address _borrower) external view returns (uint256 ltv);

    /// @notice Retrieves the fee details in 18 decimals points and the addresses of the DAO and deployer fee receivers
    /// @param _silo Address of the silo
    /// @return daoFeeReceiver The address of the DAO fee receiver
    /// @return deployerFeeReceiver The address of the deployer fee receiver
    /// @return daoFee The total fee for the DAO in 18 decimals points
    /// @return deployerFee The total fee for the deployer in 18 decimals points
    function getFeesAndFeeReceivers(ISilo _silo)
        external
        view
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee);

    /// @notice Get underlying balance of all deposits of given token of given user including "collateralOnly"
    /// deposits
    /// @dev It reads directly from storage so interest generated between last update and now is not taken for account
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @param _borrower wallet address for which to read data
    /// @return balance of underlying tokens for the given `_borrower`
    function collateralBalanceOfUnderlying(ISilo _silo, address _asset, address _borrower)
        external
        view
        returns (uint256);

    /// @notice Get amount of debt of underlying token for given user
    /// @dev It reads directly from storage so interest generated between last update and now is not taken for account
    /// there is another version of `debtBalanceOfUnderlying` that matches Silo V1 interface
    /// @param _silo Silo address from which to read data
    /// @param _borrower wallet address for which to read data
    /// @return balance of underlying token owed
    function debtBalanceOfUnderlying(ISilo _silo, address _borrower) external view returns (uint256);

    /// @dev this method is to keep interface backwards compatible
    function debtBalanceOfUnderlying(ISilo _silo, address _asset, address _borrower) external view returns (uint256);
}
