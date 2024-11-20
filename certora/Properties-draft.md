* `borrow()` user borrows maxAssets returned by maxBorrow, borrow should not revert because of solvency check
* `repay()` any user that can repay the debt should be able to repay the debt
* `repay()` any other user than borrower can repay
* `repay()` user can't over repay
* `repay()` if user repay all debt, no extra debt should be created
* `repay()` should decrease the debt (for a single block)
* `repay()` should reduce only the debt of the borrower
* `repay()` should not be able to repay more than maxRepay
* `withdraw()` should never revert if liquidity for a user and a silo is sufficient even if oracle reverts
* user is always solvent after `withdraw()`
* `accrueInterest()` should never revert
* `accrueInterest()` should be invisible for any other function including other silo and share tokens
* `accrueInterest()` calling twice is the same as calling once (in a single block)
* `accrueInterest()` should never decrease total collateral and total debt
* `accrueInterest()` accruing multiple times withing the same time frame is at least as good as accruing once
* if user has debt, `borrowerCollateralSilo[user]` should be silo0 or silo1 and one of shares tokens balances should not be 0
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
* it should be impossible to mint 0 shares or burn 0 shares or transfer 0 assets inside any function in `Silo`
* check if totalAssets can be 0 if totalShares > 0 - in context of debt. We want to make sure to never divide by 0 in mulDiv.
* calling any of deposit/withdraw/repay/borrow should not change the result of convertToShares and convertToAssets (+/- 1 wei at a time).
* `updateHooks()` should call all share tokens to update their hooks
* after a call to `updateHooks()` all share tokens and silo should have the same values for hooksBefore and hooksAfter
* if user has no debt, should always be solvent and ltv == 0
* if user has debt and no collateral (bad debt), should always be insolvent
* `getCollateralAssets()` == `totalAssets[AssetTypes.COLLATERAL]` for the same block
* `getCollateralAssets()` > `totalAssets[AssetTypes.COLLATERAL]` with pending interest
* `getDebtAssets()` == `totalAssets[AssetTypes.DEBT]` for the same block
* `getDebtAssets()` > `totalAssets[AssetTypes.DEBT]` with pending interest
* `totalAssets()` == `getCollateralAssets()` always
* return value of `convertToShares()` == `previewDeposit()` == `deposit()` should always be the same
* return value of `convertToAssets()` == `previewMint()` == `mint()` should always be the same
* `deposit()`/`mint()` always increase value on any sstore operation
* collateral share token balance always increases after `deposit()`/`mint()` only for receiver
* deposit/mint/withdraw/redeem/borrow/borrowShares/repay/repayShares/borrowSameAsset should always call turnOnReentrancyProtection(), turnOffReentrancyProtection()
* `deposit()`/`mint()`/`repay()`/`repayShares()`/`borrowSameAsset()` should always call `accrueInterest()` on one (called) Silo
* `withdraw()`/`redeem()`/`borrow()`/`borrowShares()` should always call `accrueInterest()` on both Silos
* `deposit()`/`mint()`/`withdraw()`/`redeem()`/`borrow()`/`borrowShares()`/`repay()`/`repayShares()`/`borrowSameAsset()` should call `hookBefore()`, `hookAfter()` - if configured
* result of `maxWithdraw()` should never be more than liquidity of the Silo
* result of `maxWithdraw()` used as input to withdraw() should never revert
* if user has no debt and liquidity is available, shareToken.balanceOf(user) used as input to redeem(), assets from redeem() should be equal to maxWithdraw()
* `withdraw()` and `deposit()` should be equal to `transitionCollateral()` - state changes should be the same
* if user is solvent `transitionCollateral()` for `_transitionFrom` == CollateralType.Protected should never revert
* if user is NOT solvent `transitionCollateral()` always reverts
* `transitionCollateral()` for `_transitionFrom` == `CollateralType.Collateral` should revert if not enough liquidity is available
* `transitionCollateral()` should not decrease user assets by more than rounding error
* return value of `previewBorrow()` should be always equal to `borrow()`
* user must be solvent after `switchCollateralToThisSilo()`
* `borrowerCollateralSilo[user]` should be set to "this" Silo address. No other state should be changed in either Silo. ?
* apply all rules from `borrowShares()` to `borrow()`
* `borrow()` should decrease Silo balance by exactly `_assets`
* everybody can exit Silo meaning: calling `borrow()`, then `repay()`, all users should be able to `withdraw()` all funds and `withdrawFess()` withdraws all fees successfully
* `borrowShares()` should never decrease `totalAssets[AssetType.Collateral]`
* `borrowShares()` should never change `totalAssets[AssetType.Protected]` and balances of protected and collateral share tokens and total supply for each
* user should always have ltv below maxLTV after successful call to `borrowShares()`
* `borrowShares()` should always increase debt shares of the borrower
* `borrowShares()` should always increase balance of the receiver
* inverse rules should make sure that difference between before and after values are within rounding error ie. `HLP_borrowSharesAndInverse`
* apply all `repay()` rules to `repayShares()`
* `maxFlashLoan()` should return the same value before and after deposit/withdraw of protected assets and `withdrawFees()`
* `flashFee()` returns non-zero value if fee is set to non-zero value
* `flashLoan()` should never change any storage except increasing daoAndDeployerRevenue if flashloanFee is non-zero
* `flashLoan()` daoAndDeployerRevenue and Silo asset balance should increase by flashFee()
* `accrueInterestForConfig()` is equal to `accrueInterest()`. All storage should be equally updated.
* `withdrawFees()` always increases dao and/or deployer (can be empty address) balances
* `withdrawFees()` never increases daoAndDeployerRevenue in the same block
* `withdrawFees()` always reverts in a second call in the same block
* `withdrawFees()` is ghost function - it should not influence result of any other function in the system (including view functions results)
* when all debt is paid and all collateral is withdrew, `withdrawFees()` always increases dao and/or deployer (can be empty address) `balances` and `daoAndDeployerRevenue` is set to 0
* result of `previewMint()` should be equal to result of `mint()`
* result of `previewWithdraw()` should be equal to result of `withdraw()`
* result of `maxRedeem()` used as input to `redeem()` should never revert
* result of `maxRedeem()` should never be more than share token balanceOf user
* if user has no debt and liquidity is available, `maxRedeem()` output equals `shareToken.balanceOf(user)`
* `maxRepay()` should never return more than `totalAssets[AssetType.Debt]`
* user that can repay, calling `repay()` with `maxRepay()` result should never revert 
* `repay()` should not be able to repay more than `maxRepay()`
* repaying with `maxRepay()` value should burn all user share debt token balance 
* return value of `previewRepay()` should be always equal to `repay()`
* if `borrowerCollateralSilo[user]` is set from zero to non-zero value, it never goes back to zero
* if `borrowerCollateralSilo[user]` is set from zero to non-zero value, user must have balance in one of debt share tokens - excluding `switchCollateralToThisSilo()` method
* if `borrowerCollateralSilo[user]` is set from zero to non-zero value, one of the debt share token `totalSupply()` increases and `totalAssets[AssetType.Debt]` increases for one of the silos - excluding `switchCollateralToThisSilo()` method
* `setThisSiloAsCollateralSilo()` should be called only by: `borrowSameAsset`, `switchCollateralToThisSilo`
* `setOtherSiloAsCollateralSilo()` should be called only by: `borrow`, `borrowShares`
* user should never have balance of debt share token in both silos
* calling `accrueInterestForSilo(_silo)` should be equal to calling `_silo.accrueInterest()`
* calling `accrueInterestForBothSilos()` should be equal to calling `silo0.accrueInterest()` and `silo1.accrueInterest()`
* `transfer()` of any share token should never change any state on either Silo
* `getConfigsForSolvency()` collateralConfig.silo is equal `borrowerCollateralSilo[_depositOwner]` if there is debt
* `getConfigsForSolvency()` debtConfig.silo is always the silo that debt share token balance is not equal 0 or zero address otherwise
* `getConfigsForSolvency()` if no debt, both configs (collateralConfig, debtConfig) are zero
* `getConfigsForWithdraw()` depositConfig.silo is always _silo
* `getConfigsForWithdraw()` debtConfig.silo is always the silo that debt share token balance is not equal 0 or zero address otherwise
* `getConfigsForWithdraw()` if debtConfig.silo is not zero then collateralConfig.silo is not zero
* `getConfigsForWithdraw()` collateralConfig.silo is equal `borrowerCollateralSilo[_depositOwner]` if there is debt
* `getConfigsForWithdraw()` if no debt, both configs (collateralConfig, debtConfig) are zero
* `getConfigsForBorrow()` debtConfig.silo is always equal _debtSilo
* `getConfigsForBorrow()` collateralConfig.silo is always equal to other silo than _debtSilo
* `_crossReentrantStatus` all non-view functions (both silos, silo config and all share tokens) must change or read the state of `_crossReentrantStatus` except: `Silo.flashloan()`, `ShareToken.forwardTransferFromNoChecks()`
* `forwardTransferFromNoChecks()` before and after execution of any function `transferWithChecks` must be always true
* `forwardTransferFromNoChecks()` during execution of any function other than `forwardTransferFromNoChecks`, `transferWithChecks` must be always true
* `forwardTransferFromNoChecks()` is called from `PartialLiquidation.liquidationCall()` only
* if user is insolvent, it must have debt shares
* `silo0.isSolvent()` <=> `silo1.isSolvent()`
* Every external call on Silo interface calls hook contract
