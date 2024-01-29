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

- `siloData.daoAndDeployerFees` can only be changes (increased) by accrueInterest. withdrawFees can only decrease fees. 
  flashLoan can only increase fees. \
  `siloData.timestamp` can be increased by accrueInterest only. \
  Implementation: rule `VC_Silo_siloData_management`

- shareDebtToke.balanceOf(user) increases/decrease => Silo._total[ISilo.AssetType.Debt].assets increases/decrease \
  Implementation: rule `VC_Silo_debt_share_balance`

- protectedShareToken.balanceOf(user) increases/decrease => Silo._total[ISilo.AssetType.Protected].assets increases/decrease \
  Implementation: rule `VC_Silo_protected_share_balance`

- collateralShareToken.balanceOf(user) increases/decrease => Silo._total[ISilo.AssetType.Collateral].assets increases/decrease \
  Implementation: rule `VC_Silo_collateral_share_balance`

- _siloData.daoAndDeployerFees increased => Silo._total[ISilo.AssetType.Collateral].assets 
  and Silo._total[ISilo.AssetType.Debt].assets are increased too. \
  _siloData.interestRateTimestamp can only increase.
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
  Implementation: rule `VS`

- share token totalSypply is not 0 => share token totalSypply <= Silo._total[ISilo.AssetType.*].assets. \
  share token totalSypply is 0 <=> Silo._total[ISilo.AssetType.*].assets is 0
  Implementation: rule `VS`

- balance of the silo should never be less than Silo._total[ISilo.AssetType.Protected].assets
  Implementation: rule `VS`

- Available liquidity returned by the 'getLiquidity' fn should not be higher than the balance of the silo - Silo._total[ISilo.AssetType.Protected].assets. \
  Implementation: rule `VS_silo_getLiquidity_less_equal_balance`

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

- Anyone can deposit for anyone and anyone can repay anyone
  Implementation: rule `HLP_silo_anyone_for_anyone`

- Anyone can liquidate insolvent user
  Implementation: rule `HLP_silo_anyone_can_liquidate_insolvent`

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

- A user can withdraw all with max shares amount and not be able to withdraw more. \
  Implementation: rule `RA_Silo_withdraw_all_shares`

- TODO: Cross silo read-only reentrancy check. \
  Allowed methods for reentrancy: flashLoan
  Implementation: rule `RA_silo_read_only_reentrancy`

- NonReentrant modifier work correctly. \
  Implementation: rule `RA_silo_reentrancy_modifier`

- Any depositor can withdraw from the silo. \
  Implementation: rule `RA_silo_any_user_can_withdraw`

- User should not be able to borrow without collateral. \
  Implementation: rule `RA_silo_cant_borrow_without_collateral`

- User can not execute on behalf of an owner such methods as transitionCollateral, withdraw, redeem, borrow, borrowShares without approval. \
  Implementation: rule `RA_silo_cannot_execute_without_approval`

- User should be solvent after borrowing from the silo. \
  Implementation: rule `RA_silo_solvent_after_borrow`

- User should be solvent after repaying all. \
  Implementation: rule `RA_silo_solvent_after_repaying`

- User can transition only available liquidity to protected collateral. \
  Implementation: rule `RA_silo_transion_collateral_liquidity`

- User is always able to borrow/withdraw amount returned by 'getLiquidity' fn. \
  Implementation: rule `RA_silo_borrow_withdraw_getLiquidity`

- User is always able to withdraw protected collateral up to Silo._total[ISilo.AssetType.Protected].assets. \
  Implementation: rule `RA_silo_borrow_withdraw_getLiquidity`
