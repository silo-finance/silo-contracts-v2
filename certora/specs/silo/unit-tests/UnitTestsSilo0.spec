import "../_common/OnlySilo0SetUp.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

methods {
    function Silo._accrueInterest()
        internal
        returns (uint256, address) => _accrueInterestCallChecker();
}

ghost bool callToAccrueInterest;

function _accrueInterestCallChecker() returns (uint256, address) {
    callToAccrueInterest = true;

    uint256 anyValue;
    return (anyValue, siloConfig);
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "UT_Silo_accrueInterest" \
    --verify "Silo0:certora/specs/silo/unit-tests/UnitTestsSilo0.spec"
*/
rule UT_Silo_accrueInterest(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);

    require callToAccrueInterest == false;

    f(e, args);

    assert callToAccrueInterest <=> fnAllowedToCallAccrueInterest(f),
        "Only some functions can call accrueInterest";
}
