* `borrow()` user borrows maxAssets returned by maxBorrow, borrow should not revert because of solvency check
* `repay()` user that can repay the debt should be able to repay the debt
* `repay()` user can't over repay
* `repay()` if user repay all debt, no extra debt should be created
* `repay()` should decrease the debt
* `repay()` should reduce only the debt of the borrower
* `repay()` should not be able to repay more than maxRepay
* `withdraw()` should never revert if liquidity for a user and a silo is sufficient even if oracle reverts
* user is always solvent after `withdraw()`
* `_accrueInterest()` should never revert
* `_accrueInterest()` should be invisible for any other function including other silo and share tokens
* `_accrueInterest()` calling twice is the same as calling once (in a single block)
* `_accrueInterest()` should never decrease total collateral and total debt
* if user has debt, borrowerCollateralSilo[user] should be silo0 or silo1 and one of shares tokens balances should not be 0
* if user has debt silo, then share debt token of debt silo balance is > 0, apply for `getDebtSilo`, `getConfigsForWithdraw`, `getConfigsForSolvency`
* debt in two silos is impossible
* `transitionCollateral()` share tokens balances should change only for the same address (owner)
* `transitionCollateral()` should not change underlying assets balance
* `transitionCollateral()` should not increase users assets
* transitionCollateral should not decrease user assets by more than 1-2 wei
* `_protectedAssets` is always less/equal `siloBalance`
* `getLiquidity()` should always be available for withdraw
* `getCollateralAmountsWithInterest()` should never return lower values for `collateralAssetsWithInterest` and `debtAssetsWithInterest` than `_collateralAssets` and `_debtAssets` inputs.
* `getDebtAmountsWithInterest()` should never return values where `debtAssetsWithInterest` + `accruedInterest` overflows
* `getDebtAmountsWithInterest()` should never return lower value for `debtAssetsWithInterest` than `_totalDebtAssets` input
* `getDebtAmountsWithInterest()` should never return values where sum of `debtAssetsWithInterest` and `accruedInterest` overflows
* it should be impossible to mint 0 shares or burn 0 shares or transfer 0 assets inside any function in `Silo`
* check if totalAssets can be 0 if totalShares > 0 - in context of debt. We want to make sure to never divide by 0 in mulDiv.
* calling any of deposit/withdraw/repay/borrow should not change the result of convertToShares and convertToAssets (+/- 1 wei at a time).
