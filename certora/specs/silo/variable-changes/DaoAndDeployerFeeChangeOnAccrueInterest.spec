import "../_common/OnlyNotSiloSetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/IsSolventGhost.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";

ghost bool accrueInterestCalled;
ghost uint prevAccrueInterest;

/**
to speed up checking if rule works use "--method",
certoraRun certora/config/silo/notSiloAccrueInterest.conf \
    --parametric_contracts NotSiloAccrueInterest \
    --msg "Viriables change NotSiloAccrueInterest" \
    --verify "NotSiloAccrueInterest:certora/specs/silo/variable-changes/DaoAndDeployerFeeChangeOnAccrueInterest.spec"
    --method "deposit(uint256,address)"
*/
rule VC_Silo_dao_and_deployer_fees(
    env e,
    method f,
    address receiver,
    uint256 assets
)
    filtered { f -> !f.isView && !f.isFallback }
{
    silo0SetUp(e);

    prevAccrueInterest = currentContract.getSiloDataDaoAndDeployerFees();

    calldataarg args;
    f(e, args);

    assert prevAccrueInterest == currentContract.getSiloDataDaoAndDeployerFees();

}


// we are hooking here on "CALL" opcodes in order to catch internal _accruedInterest call
hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    called_extcall = true;
    env e;
    bool cond;

    if (g_sighash == sig:_accrueInterest().selector) {
        accrueInterestCalled = true;
        assert prevAccrueInterest == currentContract.getSiloDataDaoAndDeployerFees(), "should be no changes yet";
    }
}

hook Sstore C.totalSupply uint ts (uint old_ts) STORAGE {
}
