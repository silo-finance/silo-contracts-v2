# Properties of Silo

## Types of Properties

- Variable Changes
- Unit Tests
- Valid State

### Unit Tests
- accrueInterest can only be executed on deposit, mint, withdraw,
  redeem, liquidationCall, accrueInterest, leverage.\
  Implementation: rule `UT_Silo_accrueInterest`

### Variable Changes

- collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should increase only on deposit and mint. accrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets. The balance of the silo in the underlying asset should increase for the same amount as Silo._total[ISilo.AssetType.Collateral].assets increased.
  Implementation: rule `VC_Silo_total_collateral_increase`

- collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should decrease only on withdraw, redeem, liquidationCall.The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Collateral].assets decreased.
  Implementation: rule `VC_Silo_total_collateral_decrease`

- protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets should increase only on deposit and mint. The balance of the silo in the underlying asset should increase for the same amount as Silo._total[ISilo.AssetType.Protected].assets increased.
  Implementation: rule `VC_Silo_total_protected_increase`

- protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets should decrease only on withdraw, redeem, liquidationCall. The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Protected].assets decreased.
  Implementation: rule `VC_Silo_total_protected_decrease`

- debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should increase only on borrow, borrowShares, leverage. The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Debt].assets increased.
  Implementation: rule `VC_Silo_total_debt_increase`

- debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should decrease only on repay, repayShares, liquidationCall. accrueInterest increase only Silo._total[ISilo.AssetType.Debt].assets. The balance of the silo in the underlying asset should increase for the same amount as Silo._total[ISilo.AssetType.Debt].assets decreased.
  Implementation: rule `VC_Silo_total_debt_decrease`

- _siloData.daoAndDeployerFees can only change on accrueInterest.\
  Implementation: rule `VC_Silo_dao_and_deployer_fees`

- _siloData.interestRateTimestamp can only increase on accrueInterest, it hould not change if the block.timestamp did not change.\
  Implementation: rule `VC_Silo_interestRateTimestamp_accrueInterest`

* Discuss
- shareDebtToke.balanceOf(user) increases => Silo._total[ISilo.AssetType.Debt].assets increase

- protectedShareToken.balanceOf(user) increases => Silo._total[ISilo.AssetType.Protected].assets increases

- collateralShareToken.balanceOf(user) increases => Silo._total[ISilo.AssetType.Collateral].assets increases

- _siloData.daoAndDeployerFees increased => _siloData.interestRateTimestamp and
  Silo._total[ISilo.AssetType.Collateral].assets, and Silo._total[ISilo.AssetType.Debt].assets are increased too.\
  Implementation: rule `VS_Silo_daoAndDeployerFees_and_totals`

### Valid States

- Silo._total[ISilo.AssetType.Collateral].assets is zero <=> collateralShareToken.totalSupply is zero.\
  Silo._total[ISilo.AssetType.Protected].assets is zero <=> protectedShareToken.totalSupply is zero.\
  Silo._total[ISilo.AssetType.Debt].assets is zero <=> debtShareToken.totalSupply is zero.\
  Implementation: rule `VS_Silo_totals_share_token_totalSupply`

- _siloData.interestRateTimestamp is zero => _siloData.daoAndDeployerFees is zero.\
  Implementation: rule `VS_Silo_interestRateTimestamp_daoAndDeployerFees`

* Discuss 41, 43, 45 and 62, 65
- Silo._total[ISilo.AssetType.Debt].assets is not zero => Silo._total[ISilo.AssetType.Collateral].assets is not zero.\
  Implementation: rule `VS_Silo_totalBorrowAmount`

- shareDebtToke.balanceOf(user) is not zero => protectedShareToken.balanceOf(user) + collateralShareToken.balanceOf(user) is not zero

### State Transitions

- _siloData.interestRateTimestamp is changed and it was not 0
  and Silo._total[ISilo.AssetType.Debt].assets was not 0 =>
  Silo._total[ISilo.AssetType.Debt].assets is changed.\
  Implementation: rule `ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency`

- _siloData.interestRateTimestamp is changed and it was not 0
  and Silo._total[ISilo.AssetType.Debt].assets was not 0 and Silo.getFeesAndFeeReceivers().daoFee or Silo.getFeesAndFeeReceivers().deployerFee was not 0 => _siloData.daoAndDeployerFees increased.\
  Implementation: rule `ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency`

### High-Level Properties

- Inverse deposit - withdraw for collateralToken. For any user, the balance before deposit
  should be equal to the balance after depositing and then withdrawing the same amount.\
  Implementation: rule `HLP_inverse_deposit_withdraw_collateral`

- Inverse deposit - redeem for collateralToken. For any user, the balance before deposit
  should be equal to the balance after depositing and then withdrawing the same amount.\
  Implementation: rule `HLP_inverse_deposit_redeem_collateral`

- Inverse mint - withdraw for collateralToken. For any user, the balance before deposit
  should be equal to the balance after depositing and then withdrawing the same amount.\
  Implementation: rule `HLP_inverse_mint_withdraw_collateral`

- Inverse mint - redeem for collateralToken. For any user, the balance before deposit
  should be equal to the balance after depositing and then withdrawing the same amount.\
  Implementation: rule `HLP_inverse_mint_redeem_collateral`

- Inverse borrow - repay for debtToken. For any user, the balance before borrowing should be equal
  to the balance after borrowing and then repaying the same amount.\
  Implementation: rule `HLP_inverse_borrow_repay_debtToken`
