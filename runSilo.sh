certoraRun.py certora/config/silo/mathLib.conf
certoraRun.py certora/config/silo/whoCanCallSetSilo.conf

# debt in both silos:
certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts Silo0 --msg "debtInBoth - Silo0"
certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts ShareDebtToken0 --msg "debtInBoth - ShareDebtToken0"

# customerSuggested.conf - all, by rule
certoraRun.py certora/config/silo/customerSuggested.conf --rule accrueInterest_neverReverts --msg accrueInterest_neverReverts
certoraRun.py certora/config/silo/customerSuggested.conf --rule noDebt_thenSolventAndNoLTV --msg noDebt_thenSolventAndNoLTV
certoraRun.py certora/config/silo/customerSuggested.conf --rule accrueInterest_idempotent --msg accrueInterest_idempotent
certoraRun.py certora/config/silo/customerSuggested.conf --rule withdrawFees_revertsSecondTime --msg withdrawFees_revertsSecondTime
certoraRun.py certora/config/silo/customerSuggested.conf --rule withdrawFees_increasesDaoDeploerFees --msg withdrawFees_increasesDaoDeploerFees
certoraRun.py certora/config/silo/customerSuggested.conf --rule withdrawFees_noAdditionalEffect --msg withdrawFees_noAdditionalEffect
certoraRun.py certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_neverSetToZero --msg borrowerCollateralSilo_neverSetToZero
certoraRun.py certora/config/silo/customerSuggested.conf --rule accrueInterestForSilo_equivalent --msg accrueInterestForSilo_equivalent
certoraRun.py certora/config/silo/customerSuggested.conf --rule insolventHaveDebtShares --msg insolventHaveDebtShares
certoraRun.py certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_setNonzeroIncreasesDebt --msg borrowerCollateralSilo_setNonzeroIncreasesDebt
certoraRun.py certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_setNonzeroIncreasesBalance --msg borrowerCollateralSilo_setNonzeroIncreasesBalance
certoraRun.py certora/config/silo/customerSuggested.conf --rule withdrawOnlyRevertsOnLiquidity --msg withdrawOnlyRevertsOnLiquidity
certoraRun.py certora/config/silo/customerSuggested.conf --rule solventAfterWithdraw --msg solventAfterWithdraw
certoraRun.py certora/config/silo/customerSuggested.conf --rule debt_thenBorrowerCollateralSiloSetAndHasShares --msg debt_thenBorrowerCollateralSiloSetAndHasShares
certoraRun.py certora/config/silo/customerSuggested.conf --rule noDebtInBothSilos --msg noDebtInBothSilos
certoraRun.py certora/config/silo/customerSuggested.conf --rule flashFee_nonZero --msg flashFee_nonZero

certoraRun.py certora/config/silo/access-single-silo.conf
certoraRun.py certora/config/silo/accrue_hooks.conf

runAccrue.sh

certoraRun.py certora/config/silo/authorized_functions.conf
certoraRun.py certora/config/silo/maxCorectness.conf
certoraRun.py certora/config/silo/methods_integrity.conf
certoraRun.py certora/config/silo/noDebtInBoth.conf
certoraRun.py certora/config/silo/preview_integrity.conf
certoraRun.py certora/config/silo/risk_assessment_silo.conf
certoraRun.py certora/config/silo/risk_assessment.conf
certoraRun.py certora/config/silo/silo_config.conf
certoraRun.py certora/config/silo/solvent_user.conf # run parametric contracts separatelly 
certoraRun.py certora/config/silo/third_party_protections.conf
