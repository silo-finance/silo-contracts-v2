// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";
import {IPartialLiquidation} from "./IPartialLiquidation.sol";

/*
    function getUtilization(ISilo _silo, address _asset) external view returns (uint256) {}
    function depositAPY(ISilo _silo, address _asset) external view returns (uint256) {}
    function calcFee(uint256 _amount) external view returns (uint256) {}
    function lensPing() external pure returns (bytes4) {}
    function borrowAPY(ISilo _silo, address _asset) public view returns (uint256) {}
    function totalDepositsWithInterest(ISilo _silo, address _asset) public view returns (uint256 _totalDeposits) {}
    function getDepositAmount(ISilo _silo, address _asset, address _user, uint256 _timestamp) public view returns (uint256 totalUserDeposits){}
    function totalBorrowAmountWithInterest(ISilo _silo, address _asset) public view returns (uint256 _totalBorrowAmount){}
    function balanceOfUnderlying(uint256 _assetTotalDeposits, IShareToken _shareToken, address _user){}
    function getModel(ISilo _silo, address _asset) public view returns (IInterestRateModel) {}
}
*/
interface ISiloLens {
    error InvalidAsset();

    /// @dev [v1 compatible] calculates solvency
    /// @notice this is backwards compatible method, you can use `_silo.isSolvent(_user)` directly.
    /// @param _silo Silo address from which to read data
    /// @param _user wallet address
    /// @return true if solvent, false otherwise
    function isSolvent(ISilo _silo, address _user) external view returns (bool);

    /// @dev [v1 compatible] Amount of token that is available for borrowing.
    /// @notice this is backwards compatible method, you can use `_silo.getLiquidity()`
    /// @param _silo Silo address from which to read data
    /// @param _asset borrowable asset
    /// @return Silo liquidity
    function liquidity(ISilo _silo, address _asset) external view returns (uint256);

    /// @return liquidity based on contract state (without interest, fees)
    function getRawLiquidity(ISilo _silo) external view returns (uint256 liquidity);

    /// @notice Retrieves the maximum loan-to-value (LTV) ratio
    /// @param _silo Address of the silo
    /// @return maxLtv The maximum LTV ratio configured for the silo in 18 decimals points
    function getMaxLtv(ISilo _silo) external view returns (uint256 maxLtv);

    /// @notice Get combined maximum Loan-To-Value for a user
    /// @dev [v1 compatible] In V1 LTV was per _borrower, that's why we have _borrower in arguments, but it is ignored.
    /// You can simply use getMaxLtv(_silo).
    /// @param _silo Silo address from which to read data
    /// @param _borrower ignored
    /// @return maximumLTV Maximum Loan-To-Value for silo
    function getUserMaximumLTV(ISilo _silo, address _user) external view returns (uint256 maximumLTV);

    /// @notice Retrieves the LT value
    /// @param _silo Address of the silo
    /// @return lt The LT value in 18 decimals points
    function getLt(ISilo _silo) external view returns (uint256 lt);

    /// @notice Get liquidation threshold
    /// @dev [v1 compatible] In V2 LT is constant, so you can use `getLt(silo)` directly.
    /// @param _silo Silo address from which to read data
    /// @param _borrower ignored
    /// @return liquidationThreshold liquidation threshold for silo
    function getUserLiquidationThreshold(ISilo _silo, address _borrower)
        external
        view
        returns (uint256 liquidationThreshold);

    /// @notice Retrieves the loan-to-value (LTV) for a specific borrower
    /// @dev [v1 compatible]
    /// @param _silo Address of the silo
    /// @param _borrower Address of the borrower
    /// @return userLTV The LTV for the borrower in 18 decimals points
    function getUserLTV(ISilo _silo, address _borrower) external view returns (uint256 userLTV);

    /// @notice Retrieves the loan-to-value (LTV) for a specific borrower
    /// @param _silo Address of the silo
    /// @param _borrower Address of the borrower
    /// @return ltv The LTV for the borrower in 18 decimals points
    function getLtv(ISilo _silo, address _borrower) external view returns (uint256 ltv);

    /// @notice Check if user has position in any asset in a market
    /// @dev [v1 compatible]
    /// @param _silo Silo address from market (can be silo0 or silo1)
    /// @param _borrower wallet address for which to read data
    /// @return TRUE if user has position in any asset
    function hasPosition(ISilo _silo, address _borrower) external view returns (bool);

    /// @notice Check if user is in debt
    /// @dev [v1 compatible]
    /// @param _silo Silo address from which to read data
    /// @param _borrower wallet address for which to read data
    /// @return TRUE if user borrowed any amount of any asset, otherwise FALSE
    function inDebt(ISilo _silo, address _borrower) external view returns (bool);

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

    /// @notice Retrieves the interest rate model
    /// @param _silo Address of the silo
    /// @return irm InterestRateModel contract address
    function getInterestRateModel(ISilo _silo) external view returns (address irm);
    
    /// @notice Calculates current borrow interest rate
    /// @param _silo Address of the silo
    /// @return borrowAPR The interest rate value in 18 decimals points. 10**18 is equal to 100% per year
    function getBorrowAPR(ISilo _silo) external view returns (uint256 borrowAPR);

    /// @notice Calculates current deposit interest rate.
    /// @param _silo Address of the silo
    /// @return depositAPR The interest rate value in 18 decimals points. 10**18 is equal to 100% per year.
    function getDepositAPR(ISilo _silo) external view returns (uint256 depositAPR);

    /// @notice Get underlying balance of all deposits of given token of given user including "collateralOnly"
    /// deposits
    /// @dev It reads directly from storage so interest generated between last update and now is not taken for account
    /// there is another version of `collateralBalanceOfUnderlying` that matches Silo V1 interface
    /// @param _silo Silo address from which to read data
    /// @param _borrower wallet address for which to read data
    /// @return balance of underlying tokens for the given `_borrower`
    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        external
        view
        returns (uint256);

    /// @dev [v1 compatible] this method is to keep interface backwards compatible
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

    /// @dev [v1 compatible] this method is to keep interface backwards compatible
    function debtBalanceOfUnderlying(ISilo _silo, address _asset, address _borrower) external view returns (uint256);

    /// @param _silo silo where borrower has debt
    /// @param _hook hook for silo with debt
    /// @param _borrower borrower address
    /// @return collateralToLiquidate underestimated amount of collateral liquidator will get
    /// @return debtToRepay debt amount needed to be repay to get `collateralToLiquidate`
    /// @return sTokenRequired TRUE, when liquidation with underlying asset is not possible because of not enough
    /// liquidity
    /// @return fullLiquidation TRUE if position has to be fully liquidated
    function maxLiquidation(ISilo _silo, IPartialLiquidation _hook, address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired, bool fullLiquidation);

    /// @notice Get amount of underlying asset that has been deposited to Silo
    /// @dev [v1 compatible] It reads directly from storage so interest generated between last update and now is not
    /// taken for account
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @return amount of all deposits made for given asset
    function totalDeposits(ISilo _silo, address _asset) external view returns (uint256);

    /// @notice Get amount of protected asset token that has been deposited to Silo
    /// @dev [v1 compatible] It reads directly from storage so interest generated between last update and now is not
    /// taken for account
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @return amount of all "collateralOnly" deposits made for given asset
    function collateralOnlyDeposits(ISilo _silo, address _asset) external view returns (uint256);

    /// @notice Get amount of asset that has been borrowed
    /// @dev [v1 compatible] It reads directly from storage so interest generated between last update and now is not
    /// taken for account
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @return amount of asset that has been borrowed
    function totalBorrowAmount(ISilo _silo, address _asset) external view returns (uint256);

    /// @notice Get totalSupply of debt token
    /// @dev [v1 compatible] Debt token represents a share in total debt of given asset
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @return totalSupply of debt token
    function totalBorrowShare(ISilo _silo, address _asset) external view returns (uint256);

    /// @notice Calculates current borrow amount for user with interest
    /// @dev [v1 compatible] Interest is calculated based on the provided timestamp with is expected to be current time.
    /// @param _silo Silo address from which to read data
    /// @param _asset token address for which calculation are done
    /// @param _user account for which calculation are done
    /// @param _timestamp timestamp used for interest calculations
    /// @return total amount of asset user needs to repay at provided timestamp
    function getBorrowAmount(ISilo _silo, address _asset, address _user, uint256 _timestamp)
        external
        view
        returns (uint256);

    /// @notice Get debt token balance of a user
    /// @dev [v1 compatible] Debt token represents a share in total debt of given asset.
    /// This method calls balanceOf(_borrower) on that token.
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @param _borrower wallet address for which to read data
    /// @return balance of debt token of given user
    function borrowShare(ISilo _silo, address _asset, address _borrower) external view returns (uint256);

    /// @notice Get amount of fees earned by protocol to date
    /// @dev [v1 NOT compatible] It reads directly from storage so interest generated between last update and now is not
    /// taken for account. In SiloLens v1 this was total (ever growing) amount, in this one is since last withdraw.
    /// @param _silo Silo address from which to read data
    /// @param _asset asset address for which to read data
    /// @return amount of fees earned by protocol to date since last withdraw
    function protocolFees(ISilo _silo, address _asset) external view returns (uint256);

    /// @notice Calculate value of collateral asset for user
    /// @dev [v1 NOT compatible] It dynamically adds interest earned. Takes for account protected deposits as well.
    /// In v1 result is always in 18 decimals, here it depends on oracle setup.
    /// @param _silo Silo address from which to read data
    /// @param _borrower account for which calculation are done
    /// @param _asset token address for which calculation are done
    /// @return value of collateral denominated in quote token, decimal depends on oracle setup.
    function calculateCollateralValue(ISilo _silo, address _borrower, address _asset) external view returns (uint256);

    /// @notice Calculate value of borrowed asset by user
    /// @dev [v1 NOT compatible] It dynamically adds interest earned to borrowed amount
    /// In v1 result is always in 18 decimals, here it depends on oracle setup.
    /// @param _silo Silo address from which to read data
    /// @param _borrower account for which calculation are done
    /// @param _asset token address for which calculation are done
    /// @return value of debt denominated in quote token, decimal depends on oracle setup.
    function calculateBorrowValue(ISilo _silo, address _borrower, address _asset) external view returns (uint256);

}
