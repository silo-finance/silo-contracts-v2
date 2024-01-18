# Properties of Silo

## Types of Properties

- Variable Changes
- Unit Tests
- Valid State
- High-Level Properties
- Risk Assessment

### Unit Tests
- accrueInterest can only be executed on deposit, mint, withdraw,
  redeem, liquidationCall, accrueInterest, leverage.\
  Implementation: rule `UT_Silo_accrueInterest`

### Variable Changes

- collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should increase only on deposit and mint. accrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets. The balance of the silo in the underlying asset should increase for the same amount as Silo._total[ISilo.AssetType.Collateral].assets increased. \
  Implementation: rule `VC_Silo_total_collateral_increase`

- collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should decrease only on withdraw, redeem, liquidationCall.The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Collateral].assets decreased.
  Implementation: rule `VC_Silo_total_collateral_decrease` \

- protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets should increase only on deposit and mint. The balance of the silo in the underlying asset should increase for the same amount as Silo._total[ISilo.AssetType.Protected].assets increased.
  Implementation: rule `VC_Silo_total_protected_increase` \

- protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets should decrease only on withdraw, redeem, liquidationCall. The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Protected].assets decreased.
  Implementation: rule `VC_Silo_total_protected_decrease` \

- debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should increase only on borrow, borrowShares, leverage. The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Debt].assets increased.
  Implementation: rule `VC_Silo_total_debt_increase` \

- debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should decrease only on repay, repayShares, liquidationCall. accrueInterest increase only Silo._total[ISilo.AssetType.Debt].assets. The balance of the silo in the underlying asset should increase for the same amount as Silo._total[ISilo.AssetType.Debt].assets decreased. \
  Implementation: rule `VC_Silo_total_debt_decrease`

- _siloData.daoAndDeployerFees can only change on accrueInterest. \
  Implementation: rule `VC_Silo_dao_and_deployer_fees`

- _siloData.interestRateTimestamp can only increase on accrueInterest, it hould not change if the block.timestamp did not change. \
  Implementation: rule `VC_Silo_interestRateTimestamp_accrueInterest`

- shareDebtToke.balanceOf(user) increases/decrease => Silo._total[ISilo.AssetType.Debt].assets increases/decrease \
  Implementation: rule `VC_Silo_debt_share_balance`

- protectedShareToken.balanceOf(user) increases/decrease => Silo._total[ISilo.AssetType.Protected].assets increases/decrease \
  Implementation: rule `VC_Silo_protected_share_balance`

- collateralShareToken.balanceOf(user) increases/decrease => Silo._total[ISilo.AssetType.Collateral].assets increases/decrease \
  Implementation: rule `VC_Silo_collateral_share_balance`

- _siloData.daoAndDeployerFees increased => _siloData.interestRateTimestamp and
  Silo._total[ISilo.AssetType.Collateral].assets, and Silo._total[ISilo.AssetType.Debt].assets are increased too. \
  Implementation: rule `VS_Silo_daoAndDeployerFees_and_totals`

### Valid States

- Silo._total[ISilo.AssetType.Collateral].assets is zero <=> collateralShareToken.totalSupply is zero. \
  Silo._total[ISilo.AssetType.Protected].assets is zero <=> protectedShareToken.totalSupply is zero. \
  Silo._total[ISilo.AssetType.Debt].assets is zero <=> debtShareToken.totalSupply is zero. \
  Implementation: rule `VS_Silo_totals_share_token_totalSupply`

- _siloData.interestRateTimestamp is zero => _siloData.daoAndDeployerFees is zero. \
  Implementation: rule `VS_Silo_interestRateTimestamp_daoAndDeployerFees`

- Silo._total[ISilo.AssetType.Debt].assets is not zero => Silo._total[ISilo.AssetType.Collateral].assets is not zero. \
  Implementation: rule `VS_Silo_totalBorrowAmount`

- shareDebtToke.balanceOf(user) is not zero => protectedShareToken.balanceOf(user) + collateralShareToken.balanceOf(user) is zero

- share token totalSypply is not 0 => share token totalSypply <= Silo._total[ISilo.AssetType.*].assets. \
  share token totalSypply is 0 <=> Silo._total[ISilo.AssetType.*].assets is 0

### State Transitions

- _siloData.interestRateTimestamp is changed and it was not 0
  and Silo._total[ISilo.AssetType.Debt].assets was not 0 =>
  Silo._total[ISilo.AssetType.Debt].assets is changed.\
  Implementation: rule `ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency`

- _siloData.interestRateTimestamp is changed and it was not 0
  and Silo._total[ISilo.AssetType.Debt].assets was not 0 and Silo.getFeesAndFeeReceivers().daoFee or Silo.getFeesAndFeeReceivers().deployerFee was not 0 => _siloData.daoAndDeployerFees increased.\
  Implementation: rule `ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency`

### High-Level Properties

- Inverse deposit - withdraw for collateralToken. For any user, the balance before deposit should be equal to the balance after depositing and then withdrawing the same amount. Silo Silo._total[ISilo.AssetType.*].assets should be the same.\
  Implementation: rule `HLP_inverse_deposit_withdraw_collateral`\
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares.

- Additive deposit for the state while do deposit(x + y)
  should be the same as deposit(x) + deposit(y). \
  Implementation: rule `HLP_additive_deposit_collateral` \
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares, transitionCollateral.

- Integrity of deposit for collateralToken, Silo._total[ISilo.AssetType.Collateral].assets after deposit
  should be equal to the Silo._total[ISilo.AssetType.Collateral].assets before deposit + amount of the deposit. \
  Implementation: rule `HLP_integrity_deposit_collateral` \
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares, transitionCollateral.

- Deposit of the collateral will update the balance of only recepient. \
  Implementation: rule `HLP_deposit_collateral_update_only_recepient` \
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares.

- Transition of the collateral will increase one balance and decrease another of only owner. \
  Implementation: rule `HLP_transition_collateral_update_only_recepient`

- LiquidationCall will only update the balances of the provided user. \
  Implementation: rule `HLP_liquidationCall_shares_tokens_balances`

### Risk Assessment

- A user cannot withdraw anything after withdrawing whole balance. \
  Implementation: rule `RA_Silo_no_withdraw_after_withdrawing_all`

- A user should not be able to fully repay a loan with less amount than he borrowed. \
  Implementation: rule `RA_Silo_no_negative_interest_for_loan`

- With protected collateral deposit, there is no scenario when the balance of a contract is less than that deposit amount. \
  Implementation: rule `RA_Silo_balance_more_than_protected_collateral_deposit`

- A user should not be able to deposit an asset that he borrowed in the Silo. \
  Implementation: rule `RA_Silo_borrowed_asset_not_depositable`

- A user has no debt after being repaid with max shares amount. \
  Implementation: rule `RA_Silo_repay_all_shares`

- A user can withdraw all with max shares amount. \
  Implementation: rule `RA_Silo_withdraw_all_shares`
