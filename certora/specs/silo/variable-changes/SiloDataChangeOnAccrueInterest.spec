import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_simplifications/IsSolventGhost.spec";
import "../_simplifications/AccrueInterestSimplification.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";


/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/SiloDataChangeOnAccrueInterest.spec"
    --parametric_contracts Silo0 \
    --msg "SiloDataChangeOnAccrueInterest"  --method "deposit(uint256,address)" // to speed up use --method flag
*/
rule VC_Silo_siloData_change_on_accrueInterest(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 prevAccrueInterest = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();

    calldataarg args;
    f(e, args);

    assert
        prevAccrueInterest == currentContract.getSiloDataDaoAndDeployerFees(),
        "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change fees";

    assert
        prevTimestamp == currentContract.getSiloDataInterestRateTimestamp(),
        "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change timestamp";
}
