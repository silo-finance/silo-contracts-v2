import "../_common/CommonSummarizations.spec";
import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/Silo_noAccrueInterest_simplification.spec";
import "../../_simplifications/Token_transfer_simplification.spec";
import "../../_simplifications/MulDiv_simplification.spec";
import "../../_simplifications/Sqrt_simplification.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/VC_Silo_siloData_management.spec" \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_siloData_management" \
    --method "flashLoan(address,address,uint256,bytes)" // to speed up use --method flag
*/
rule VC_Silo_siloData_management(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 accrueInterestBefore = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();
    uint256 flashloanFee = currentContract.getFlashloanFee0();

    uint256 flashloanAmount;
    address receiver;

    siloFnSelector(e, f, flashloanAmount, receiver);

    uint256 accrueInterestAfter = currentContract.getSiloDataDaoAndDeployerFees();

    if (f.selector == withdrawFeesSig()) {
        assert accrueInterestBefore == 0 => accrueInterestAfter == 0;

        assert accrueInterestBefore > 0 => accrueInterestBefore > accrueInterestAfter, 
            "withdrawFees can only decrease fee";

        assert  accrueInterestBefore >= accrueInterestAfter,  "withdrawFees() is able to decrease fees";
    } else if (f.selector == flashLoanSig()) {
        if (flashloanAmount > 0 && flashloanFee > 0) {
            assert accrueInterestBefore < accrueInterestAfter, "flashLoan will increase fees";
        } else {
            assert accrueInterestBefore == accrueInterestAfter, "when no fee or no amount => no change to fees";
        }
    } else {
        assert accrueInterestBefore == accrueInterestAfter,
            "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change fees";
    }

    assert prevTimestamp == currentContract.getSiloDataInterestRateTimestamp(),
        "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change timestamp";
}
