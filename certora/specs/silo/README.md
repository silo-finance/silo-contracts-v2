# Properties of Silo

## Types of Properties

- Variable Changes
- Unit Tests

### Unit Tests
- accrueInterest can only be executed on deposit, mint, withdraw,
  redeem, liquidationCall, accrueInterest, leverage.\
  Implementation: rule `UT_Silo_accrueInterest`

### Variable Changes

- collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should increase only on deposit and mint. accrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets.
  Protected and Debt with totalSupply should not change.\
  Implementation: rule `VC_Silo_total_collateral_increase`

- collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should decrease only on withdraw, redeem, liquidationCall.
  Protected and Debt with totalSupply should not change.\
  Implementation: rule `VC_Silo_total_collateral_decrease`

- protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets should increase only on deposit and mint.
  Collateral and Debt with totalSupply should not change.\
  Implementation: rule `VC_Silo_total_protected_increase`

- protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets should decrease only on withdraw, redeem, liquidationCall.
  Collateral and Debt with totalSupply should not change.\
  Implementation: rule `VC_Silo_total_protected_decrease`

- debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should increase only on borrow, borrowShares, leverage.
  Collateral and Protected with totalSupply should not change.\
  Implementation: rule `VC_Silo_total_debt_increase`

- debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should decrease only on repay, repayShares, liquidationCall. accrueInterest increase only Silo._total[ISilo.AssetType.Debt].assets.
  Collateral and Protected with totalSupply should not change.\
  Implementation: rule `VC_Silo_total_debt_decrease`

- _siloData.daoAndDeployerFees can only change on accrueInterest.\
  Implementation: rule `VC_Silo_dao_and_deployer_fees`

- _siloData.interestRateTimestamp can only change on accrueInterest, it hould not change if the block.timestamp did not change.\
  Implementation: rule `VC_Silo_interestRateTimestamp_accrueInterest`
