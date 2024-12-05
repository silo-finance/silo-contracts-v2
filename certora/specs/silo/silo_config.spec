/* The specification of the Silo configs */

import "../requirements/two_silos_tokens_requirements.spec";
import "../summaries/two_silos_summaries.spec";
import "../summaries/interest_rate_model_v2.spec";
import "../summaries/siloconfig_dispatchers.spec";

// ---- Rules and Invariants ----------------------------------------------------

/// @dev rule 109 :
//       calling accrueInterestForBothSilos() should be equal to
//       calling silo0.accrueInterest() and silo1.accrueInterest()
/// @status Done

rule accrueInterestConsistency() {
    storage initial = lastStorage;
    
    env e ;
    silosTimestampSetupRequirements(e);

    // call accrueInterestForBothSilos()
    accrueInterestForBothSilos(e) ;

    storage single_call = lastStorage ;

    // call silo1.accrueInterest() then silo0.accrueInterest()
    silo1.accrueInterest(e) at initial ;
    silo0.accrueInterest(e) ;

    storage separate_calls_10 = lastStorage ;
    
    // call silo0.accrueInterest() then silo1.accrueInterest()
    silo0.accrueInterest(e) at initial ;
    silo1.accrueInterest(e) ;

    storage separate_calls_01 = lastStorage ;

    // compare assets in both silos to ensure they are equal 
    assert (
        separate_calls_10 == single_call &&
        separate_calls_01 == single_call
    ) ;
}


/// @dev this is an invariant that needs to be proved for the preview integrity rules
/// @status violation
invariant assetsZeroInterestRateTimestampZero(env e)
    silo0.getCollateralAssets(e) > 0 || silo0.getDebtAssets(e) > 0 =>
    silo0.getSiloDataInterestRateTimestamp(e) > 0 ;