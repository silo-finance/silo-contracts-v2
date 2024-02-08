import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloMethods.spec";
import "../_common/SiloFunctionSig.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "Silo0 risk assessment" \
    --verify "Silo0:certora/specs/silo/risk-assessment/RiskAssessmentSilo0.spec"
*/
rule RA_silo_reentrancy_modifier(env e, method f, calldataarg args) filtered { f -> !f.isView } {
    silo0SetUp(e);

    require reentrancyGuardEntered();

    storage storageBeforeCall = lastStorage;

    f(e, args);

    storage storageAfterCall = lastStorage;

    bool fnAllowedToModifyStorage = transferSig() == f.selector ||
                                    approveSig() == f.selector ||
                                    withdrawFeesSig() == f.selector ||
                                    flashLoanSig() == f.selector ||
                                    initializeSig() == f.selector ||
                                    accrueInterestSig() == f.selector ||
                                    transferFromSig() == f.selector;

    assert !fnAllowedToModifyStorage => storageBeforeCall == storageAfterCall,
        "Reentrancy modifier is not working properly";
}
