import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/Silo_accrueInterest_simplification.spec";
// import "../../_simplifications/Token_transfer_simplification.spec"; TODO why I can not do it?
import "../_common/SimplifiedConvertions1to2Ratio.spec";


/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/SiloDataChangeOnAccrueInterest.spec" \
    --parametric_contracts Silo0 \
    --msg "SiloDataChangeOnAccrueInterest"  --method "withdrawFees()" // to speed up use --method flag
*/
rule VC_Silo_siloData_change_on_accrueInterest(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 prevAccrueInterest = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();

    calldataarg args;
    f(e, args);

    if (f.selector != withdrawFeesSig()) {
        assert
            prevAccrueInterest >= currentContract.getSiloDataDaoAndDeployerFees(),
            "withdrawFees() is able to decrease fees";

        assert
            prevTimestamp == currentContract.getSiloDataInterestRateTimestamp(),
            "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change timestamp";
    } else {
        assert
            prevAccrueInterest == currentContract.getSiloDataDaoAndDeployerFees(),
            "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change fees";

        assert
            prevTimestamp == currentContract.getSiloDataInterestRateTimestamp(),
            "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change timestamp";
    }
}
