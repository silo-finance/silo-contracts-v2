import "../_common/OnlySilo0SetUp.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "HLP_additive_deposit_collateral" \
    --rule "HLP_additive_deposit_collateral" \
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0.spec"
*/
rule HLP_additive_deposit_collateral(env e) {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;

    require x > 1 && x < max_uint128 && y > 1 && y < max_uint128;

    storage initialStorage = lastStorage;

    mathint xPlusY = x + y;

    deposit(e, assert_uint256(xPlusY), e.msg.sender);

    mathint balanceAfterOneDeposit = shareCollateralToken0.balanceOf(e.msg.sender);

    deposit(e, assert_uint256(x), e.msg.sender) at initialStorage;
    deposit(e, assert_uint256(y), e.msg.sender);

    mathint balanceAfterTwoDeposits = shareCollateralToken0.balanceOf(e.msg.sender);

    assert balanceAfterTwoDeposits == balanceAfterTwoDeposits,
        "depositing x + y and then x and y should be the same";
}
