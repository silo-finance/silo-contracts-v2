# Properties of Silo

## Types of Properties

- Variable Changes
- Unit Tests
- Valid State
- High-Level Properties
- Risk Assessment

### Variable Changes

- collateralShareToken.totalSupply and Silo.totalAssets[ISilo.AssetType.Collateral] should increase only on deposit, mint, and transitionCollateral. accrueInterest increase only Silo.totalAssets[ISilo.AssetType.Collateral]. The balance of the silo in the underlying asset should increase for the same amount as Silo.totalAssets[ISilo.AssetType.Collateral] increased. \
  Implementation: rule `VC_Silo_total_collateral_increase`

- collateralShareToken.totalSupply and Silo.totalAssets[ISilo.AssetType.Collateral] should decrease only on withdraw, redeem, liquidationCall.The balance of the silo in the underlying asset should decrease for the same amount as Silo.totalAssets[ISilo.AssetType.Collateral] decreased.
  Implementation: rule `VC_Silo_total_collateral_decrease` \

- protectedShareToken.totalSupply and Silo.totalAssets[ISilo.AssetType.Protected] should increase only on deposit, mint, and transitionCollateral. The balance of the silo in the underlying asset should increase for the same amount as Silo.totalAssets[ISilo.AssetType.Protected] increased. `accrueInterest` fn does not increase the protected assets.
  Implementation: rule `VC_Silo_total_protected_increase` \

- protectedShareToken.totalSupply and Silo.totalAssets[ISilo.AssetType.Protected] should decrease only on withdraw, redeem, liquidationCall, and transitionCollateral. The balance of the silo in the underlying asset should decrease for the same amount as Silo.totalAssets[ISilo.AssetType.Protected] decreased.
  Implementation: rule `VC_Silo_total_protected_decrease` \

- debtShareToken.totalSupply and Silo.totalAssets[ISilo.AssetType.Debt] should increase only on borrow, borrowShares, leverageSameAsset. The balance of the silo in the underlying asset should decrease for the same amount as Silo.totalAssets[ISilo.AssetType.Debt] increased.
  Implementation: rule `VC_Silo_total_debt_increase` \

- debtShareToken.totalSupply and Silo.totalAssets[ISilo.AssetType.Debt] should decrease only on repay, repayShares, liquidationCall. accrueInterest increase only Silo.totalAssets[ISilo.AssetType.Debt]. The balance of the silo in the underlying asset should increase for the same amount as Silo.totalAssets[ISilo.AssetType.Debt] decreased. \
  Implementation: rule `VC_Silo_total_debt_decrease`

- `siloData.daoAndDeployerFees` can only be changes (increased) by accrueInterest. withdrawFees can only decrease fees. 
  flashLoan can only increase fees. \
  `siloData.timestamp` can be increased by accrueInterest only. \
  Implementation: rule `VC_Silo_siloData_management`

- shareDebtToke.balanceOf(user) increases/decrease => Silo.totalAssets[ISilo.AssetType.Debt] increases/decrease \
  Implementation: rule `VC_Silo_debt_share_balance`

- protectedShareToken.balanceOf(user) increases/decrease => Silo.totalAssets[ISilo.AssetType.Protected] increases/decrease \
  Implementation: rule `VC_Silo_protected_share_balance`

- collateralShareToken.balanceOf(user) increases/decrease => Silo.totalAssets[ISilo.AssetType.Collateral] increases/decrease \
  Implementation: rule `VC_Silo_collateral_share_balance`

- _siloData.daoAndDeployerFees increased => Silo.totalAssets[ISilo.AssetType.Collateral] 
  and Silo.totalAssets[ISilo.AssetType.Debt] are increased too. \
  _siloData.interestRateTimestamp can only increase.
  Implementation: rule `VS_Silo_daoAndDeployerFees_and_totals`

### Valid States

- Silo.totalAssets[ISilo.AssetType.Collateral] is zero <=> collateralShareToken.totalSupply is zero. \
  Silo.totalAssets[ISilo.AssetType.Protected] is zero <=> protectedShareToken.totalSupply is zero. \
  Silo.totalAssets[ISilo.AssetType.Debt] is zero <=> debtShareToken.totalSupply is zero. \
  Implementation: rule `VS_Silo_totals_share_token_totalSupply` ?

- _siloData.interestRateTimestamp is zero => _siloData.daoAndDeployerFees is zero. \
  _siloData.daoAndDeployerFees can increase without _siloData.interestRateTimestamp only on flashLoan fn. \
  Implementation: rule `VS_Silo_interestRateTimestamp_daoAndDeployerFees`

- when user is solvent and shareDebtToke.balanceOf(user) is not zero => protectedShareToken.balanceOf(user) + collateralShareToken.balanceOf(user) is zero
  Implementation: rule `VS_Silo_debtShareToken_balance_notZero`

- balance of the silo should never be less than Silo.totalAssets[ISilo.AssetType.Protected]
  Implementation: rule `VS_Silo_balance_totalAssets`

- Available liquidity returned by the 'getLiquidity' fn should not be higher than the balance of the silo - Silo.totalAssets[ISilo.AssetType.Protected] - daoAndDeployerRevenue. \
  Implementation: rule `VS_silo_getLiquidity_less_equal_balance`

### State Transitions

- _siloData.interestRateTimestamp is changed and it was not 0
  and Silo.totalAssets[ISilo.AssetType.Debt] was not 0 =>
  Silo.totalAssets[ISilo.AssetType.Debt] increased.\
  Implementation: rule `ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency`

- _siloData.interestRateTimestamp is changed and it was not 0
  and Silo.totalAssets[ISilo.AssetType.Debt] was not 0 and Silo.getFeesAndFeeReceivers().daoFee or Silo.getFeesAndFeeReceivers().deployerFee was not 0 => _siloData.daoAndDeployerFees increased.\
  Implementation: rule `ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency`

### High-Level Properties

- Inverse deposit - withdraw for collateralToken. For any user, the balance before deposit should be equal to the balance after depositing and then withdrawing the same amount.\
  Implementation: rule `HLP_inverse_deposit_withdraw_collateral`\
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares.

- Silo Silo.totalAssets[ISilo.AssetType.*] should be the same + interest accrual.\
  Implementation: rule `HLP_inverse_deposit_withdraw_collateral_with_interest`\
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares.

- Additive deposit for the state while do deposit(x + y)
  should be the same as deposit(x) + deposit(y). \
  Implementation: rule `HLP_additive_deposit_collateral` \
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares, transitionCollateral.

- Integrity of deposit for collateralToken, Silo.totalAssets[ISilo.AssetType.Collateral] after deposit
  should be equal to the Silo.totalAssets[ISilo.AssetType.Collateral] before deposit + amount of the deposit. \
  Implementation: rule `HLP_integrity_deposit_collateral_no_interest` \
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares, transitionCollateral.

- Deposit of the collateral will update the balance of only recipient. \
  Implementation: rule `HLP_deposit_collateral_update_only_recipient` \
  Apply for mint, withdraw, redeem, repay, repayShares, borrow, borrowShares.

- Transition of the collateral will increase one balance and decrease another of only owner. \
  Implementation: rule `HLP_transition_collateral_update_only_recipient`

- LiquidationCall will only update the balances of the provided user if the liquidator do not receive share tokens. Otherwise, it should update the liquidator balance too. \
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

- With protected collateral deposit, there is no scenario when the balance of a Silo is less than that deposit amount. \
  Implementation: rule `RA_Silo_balance_more_than_protected_collateral_deposit`

- A user has no debt after being repaid with max shares amount. \
  Implementation: rule `RA_Silo_repay_all_shares`

- A user can withdraw all with max shares amount and not be able to withdraw more. \
  Implementation: rule `RA_Silo_withdraw_all_shares`

- Cross silo read-only reentrancy check. \
  Allowed methods for reentrancy: flashLoan
  Implementation: rule `RA_silo_read_only_reentrancy`

- Any depositor (protected collateral) can withdraw from the silo. \
  Implementation: rule `RA_silo_any_user_can_withdraw_protected_collateral`

- Any depositor can withdraw from the silo if liquidity is available. \
  Implementation: rule `RA_silo_any_user_can_withdraw_if_liquidity_available`

- User should not be able to borrow without collateral. \
  Implementation: rule `RA_silo_cant_borrow_without_collateral`

- User can not execute on behalf of an owner all methods except such methods as deposit, repay without approval. \
  Implementation: rule `RA_silo_cannot_execute_without_approval`

- User should be solvent after borrowing from the silo. \
  Implementation: rule `RA_silo_solvent_after_borrow`

- User should be solvent after repaying all. \
  Implementation: rule `RA_silo_solvent_after_repaying`

- User can transition only available liquidity to protected collateral. \
  Implementation: rule `RA_silo_transition_collateral_liquidity`

- User is always able to borrow/withdraw amount returned by 'getLiquidity' fn. \
  Implementation: rule `RA_silo_borrow_withdraw_getLiquidity`

- User is always able to withdraw protected collateral up to Silo.totalAssets[ISilo.AssetType.Protected]. \
  Implementation: rule `RA_silo_withdraw_protected_collateral`
