import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_ghosts/IsSolventGhost.spec";
import "../_ghosts/AccrueInterestGhost.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";


/**
to speed up checking if rule works use "--method",
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "_accrueInterest" \
    --verify "Silo0:certora/specs/silo/variable-changes/DaoAndDeployerFeeChangeOnAccrueInterest.spec"
    --method "deposit(uint256,address)"
*/
rule VC_Silo_dao_and_deployer_fees(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 prevAccrueInterest = currentContract.getSiloDataDaoAndDeployerFees();

    calldataarg args;
    f(e, args);

    assert prevAccrueInterest == currentContract.getSiloDataDaoAndDeployerFees(), "no other method should change fee";
}
