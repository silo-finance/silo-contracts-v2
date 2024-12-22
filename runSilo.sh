certoraRun certora/config/silo/maxCorectness.conf --rule HLP_MaxDeposit_reverts --msg "HLP_MaxDeposit_reverts" 
certoraRun certora/config/silo/maxCorectness.conf --rule HLP_MaxRepayShares_reverts --msg "HLP_MaxRepayShares_reverts" 
certoraRun certora/config/silo/maxCorectness.conf --rule maxRepay_burnsAllDebt --msg "maxRepay_burnsAllDebt"   
certoraRun certora/config/silo/maxCorectness.conf --rule maxWithdraw_noGreaterThanLiquidity --msg "maxWithdraw_noGreaterThanLiquidity" 

certoraRun certora/config/silo/noDebtInBoth.conf --parametric_contracts Silo0 --msg "debtInBoth - Silo0" 
certoraRun certora/config/silo/noDebtInBoth.conf --parametric_contracts ShareDebtToken0 --msg "debtInBoth - ShareDebtToken0" 

certoraRun certora/config/silo/customerSuggested.conf --rule accrueInterest_idempotent --msg accrueInterest_idempotent 
certoraRun certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_neverSetToZero --msg borrowerCollateralSilo_neverSetToZero 
certoraRun certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_setNonzeroIncreasesDebt --msg borrowerCollateralSilo_setNonzeroIncreasesDebt 
certoraRun certora/config/silo/customerSuggested.conf --rule noDebtInBothSilos --msg noDebtInBothSilos 

certoraRun certora/config/silo/access-single-silo.conf --exclude_rule RA_repay_borrower_is_not_restricted --msg access-single-silo 
certoraRun certora/config/silo/accrue_hooks.conf   
certoraRun certora/config/silo/mathLib.conf --rule getDebtAmountsWithInterest_correctness 

certoraRun certora/config/silo/methods_integrity.conf  
certoraRun certora/config/silo/risk_assessment_silo.conf 
certoraRun certora/config/silo/risk_assessment.conf    
certoraRun certora/config/silo/silo_config.conf    
certoraRun certora/config/silo/third_party_protections.conf    

# preview_integrity - by rule
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewBorrowCorrectness_strict --msg HLP_PreviewBorrowCorrectness_strict 
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewBorrowSharesCorrectness --msg HLP_PreviewBorrowSharesCorrectness 
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewDepositCorrectness --msg HLP_PreviewDepositCorrectness  
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewMintCorrectness_strict --msg HLP_PreviewMintCorrectness_strict  
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewRedeemCorrectness --msg HLP_PreviewRedeemCorrectness 
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewRepayCorrectness_strict --msg HLP_PreviewRepayCorrectness_strict 
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewRepaySharesCorrectness --msg HLP_PreviewRepaySharesCorrectness 
certoraRun certora/config/silo/preview_integrity.conf --rule HLP_PreviewWithdrawCorrectness_strict --msg HLP_PreviewWithdrawCorrectness_strict 
certoraRun certora/config/silo/preview_integrity.conf --rule solventAfterSwitch --msg solventAfterSwitch 
certoraRun certora/config/silo/preview_integrity.conf --rule transitionSucceedsIfSolvent --msg transitionSucceedsIfSolvent 

# solvent user
certoraRun certora/config/silo/solvent_user.conf --parametric_contracts Silo0 --msg "solvent_user - Silo0" 
certoraRun certora/config/silo/solvent_user.conf --parametric_contracts Token0 ShareDebtToken0 ShareProtectedCollateralToken0 --msg "solvent_user - tokens" 
