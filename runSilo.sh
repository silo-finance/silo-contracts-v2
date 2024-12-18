# certoraRun.py certora/config/silo/mathLib.conf --rule getDebtAmountsWithInterest_correctness # done

# certoraRun.py certora/config/silo/maxCorectness.conf --rule HLP_MaxDeposit_reverts --msg "HLP_MaxDeposit_reverts" # done
# certoraRun.py certora/config/silo/maxCorectness.conf --rule HLP_MaxRepayShares_reverts --msg "HLP_MaxRepayShares_reverts" # done
# certoraRun.py certora/config/silo/maxCorectness.conf --rule maxRepay_burnsAllDebt --msg "maxRepay_burnsAllDebt"   # done
# certoraRun.py certora/config/silo/maxCorectness.conf --rule maxWithdraw_noGreaterThanLiquidity --msg "maxWithdraw_noGreaterThanLiquidity" # done

# certoraRun.py certora/config/silo/methods_integrity.conf  # done
# certoraRun.py certora/config/silo/preview_integrity.conf
certoraRun.py certora/config/silo/risk_assessment_silo.conf
# certoraRun.py certora/config/silo/risk_assessment.conf    # done

# certoraRun.py certora/config/silo/silo_config.conf    # done
# certoraRun.py certora/config/silo/solvent_user.conf --parametric_contracts Silo0 --msg "solvent_user - Silo0"
# certoraRun.py certora/config/silo/solvent_user.conf --parametric_contracts Token0 ShareDebtToken0 ShareProtectedCollateralToken0 --msg "solvent_user - tokens"
# certoraRun.py certora/config/silo/third_party_protections.conf    # done

# # debt in both silos:
# certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts Silo0 --msg "debtInBoth - Silo0" # done
# certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts ShareDebtToken0 --msg "debtInBoth - ShareDebtToken0" # done

# # customerSuggested.conf, by rule
# certoraRun.py certora/config/silo/customerSuggested.conf --rule accrueInterest_idempotent --msg accrueInterest_idempotent # done
# certoraRun.py certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_neverSetToZero --msg borrowerCollateralSilo_neverSetToZero # done
# certoraRun.py certora/config/silo/customerSuggested.conf --rule borrowerCollateralSilo_setNonzeroIncreasesDebt --msg borrowerCollateralSilo_setNonzeroIncreasesDebt # done
# certoraRun.py certora/config/silo/customerSuggested.conf --rule noDebtInBothSilos --msg noDebtInBothSilos # done

# certoraRun.py certora/config/silo/access-single-silo.conf --exclude_rule RA_repay_borrower_is_not_restricted --msg access-single-silo # done
# certoraRun.py certora/config/silo/accrue_hooks.conf

# runAccrue.sh