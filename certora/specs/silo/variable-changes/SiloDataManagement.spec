import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/Silo_accrueInterest_simplification.spec";
import "../../_simplifications/Token_transfer_simplification.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";


/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/SiloDataManagement.spec" \
    --parametric_contracts Silo0 \
    --msg "SiloDataManagement (tokens simplified)" \
    --method "flashLoan(address,address,uint256,bytes)" // to speed up use --method flag
*/
rule VC_Silo_siloData_change(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 prevAccrueInterest = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();

    calldataarg args;
    f(e, args);

    if (f.selector == withdrawFeesSig()) {
        assert prevAccrueInterest == 0 => currentContract.getSiloDataDaoAndDeployerFees() == 0;

        assert
            prevAccrueInterest > 0 => prevAccrueInterest > currentContract.getSiloDataDaoAndDeployerFees(),
            "only decreasing is possible for withdrawFees";

        assert
            prevAccrueInterest >= currentContract.getSiloDataDaoAndDeployerFees(),
            "withdrawFees() is able to decrease fees";
    } else if (f.selector == flashLoanSig()) {
        assert
            prevAccrueInterest < currentContract.getSiloDataDaoAndDeployerFees(),
            "flashLoan will increase fees";
    } else {
        assert
            prevAccrueInterest == currentContract.getSiloDataDaoAndDeployerFees(),
            "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change fees";
    }

    assert
        prevTimestamp == currentContract.getSiloDataInterestRateTimestamp(),
        "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change timestamp";
}
