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
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0Additivity.spec"
*/
rule HLP_additive_deposit_collateral(env e) {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;

    requireXY(x, y);

    storage initialStorage = lastStorage;

    deposit(e, assert_uint256(x + y), e.msg.sender);

    mathint balanceAfterOneDeposit = shareCollateralToken0.balanceOf(e.msg.sender);

    deposit(e, assert_uint256(x), e.msg.sender) at initialStorage;
    deposit(e, assert_uint256(y), e.msg.sender);

    mathint balanceAfterTwoDeposits = shareCollateralToken0.balanceOf(e.msg.sender);

    assert diff_1_wei(balanceAfterTwoDeposits, balanceAfterOneDeposit),
        "depositing x + y and then x and y should be the same";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "HLP_additive_mint_collateral" \
    --rule "HLP_additive_mint_collateral" \
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0Additivity.spec"
*/
rule HLP_additive_mint_collateral(env e) {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;

    requireXY(x, y);

    storage initialStorage = lastStorage;

    mint(e, assert_uint256(x + y), e.msg.sender);

    mathint balanceAfterOneMint = shareCollateralToken0.balanceOf(e.msg.sender);

    mint(e, assert_uint256(x), e.msg.sender) at initialStorage;
    mint(e, assert_uint256(y), e.msg.sender);

    mathint balanceAfterTwoMints = shareCollateralToken0.balanceOf(e.msg.sender);

    assert balanceAfterTwoMints == balanceAfterOneMint,
        "minting x + y and then x and y should be the same";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "HLP_additive_withdraw_collateral" \
    --rule "HLP_additive_withdraw_collateral" \
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0Additivity.spec"
*/
rule HLP_additive_withdraw_collateral(env e) {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;
    address user = e.msg.sender;

    requireXY(x, y);

    mathint xPlusY = x + y;

    requireSiloAndUserBalance(xPlusY, user);

    storage initialStorage = lastStorage;

    withdraw(e, assert_uint256(xPlusY), user, user);

    mathint balanceAfterOneWithdraw = shareCollateralToken0.balanceOf(user);

    withdraw(e, assert_uint256(x), user, user) at initialStorage;
    withdraw(e, assert_uint256(y), user, user);

    mathint balanceAfterTwoWithdraws = shareCollateralToken0.balanceOf(user);

    assert balanceAfterOneWithdraw == balanceAfterTwoWithdraws,
        "withdrawing x + y and then x and y should be the same";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "HLP_additive_redeem" \
    --rule "HLP_additive_redeem" \
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0Additivity.spec"
*/
rule HLP_additive_redeem(env e) {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;
    address user = e.msg.sender;

    requireXY(x, y);

    mathint xPlusY = x + y;

    requireSiloAndUserBalance(xPlusY, user);

    storage initialStorage = lastStorage;

    redeem(e, assert_uint256(xPlusY), user, user);

    mathint balanceAfterOneRedeem = shareCollateralToken0.balanceOf(user);

    redeem(e, assert_uint256(x), user, user) at initialStorage;
    redeem(e, assert_uint256(y), user, user);

    mathint balanceAfterTwoRedeems = shareCollateralToken0.balanceOf(user);

    assert balanceAfterOneRedeem == balanceAfterTwoRedeems,
        "redeeming x + y and then x and y should be the same";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "HLP_additive_repay" \
    --rule "HLP_additive_repay" \
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0Additivity.spec"
*/
rule HLP_additive_repay(env e) {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;
    address user = e.msg.sender;

    requireXY(x, y);

    mathint xPlusY = x + y;

    requireSiloAndUserBalanceWithDebt(xPlusY, user);

    storage initialStorage = lastStorage;

    repay(e, assert_uint256(xPlusY), user);

    mathint balanceAfterOneRepay = shareDebtToken0.balanceOf(user);

    repay(e, assert_uint256(x), user) at initialStorage;
    repay(e, assert_uint256(y), user);

    mathint balanceAfterTwoRepays = shareDebtToken0.balanceOf(user);

    assert balanceAfterOneRepay == balanceAfterTwoRepays,
        "repaying x + y and then x and y should be the same";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "HLP_additive_repayShares" \
    --rule "HLP_additive_repayShares" \
    --verify "Silo0:certora/specs/silo/high-level/HighLevelSilo0Additivity.spec"
*/
rule HLP_additive_repayShares(env e) {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint x;
    mathint y;
    address user = e.msg.sender;

    requireXY(x, y);

    mathint xPlusY = x + y;

    requireSiloAndUserBalanceWithDebt(xPlusY, user);

    storage initialStorage = lastStorage;

    repayShares(e, assert_uint256(xPlusY), user);

    mathint balanceAfterOneRepay = shareDebtToken0.balanceOf(user);

    repayShares(e, assert_uint256(x), user) at initialStorage;
    repayShares(e, assert_uint256(y), user);

    mathint balanceAfterTwoRepays = shareDebtToken0.balanceOf(user);

    assert balanceAfterOneRepay == balanceAfterTwoRepays,
        "repaying x + y and then x and y should be the same";
}

function requireSiloAndUserBalance(mathint expectedBalance, address user) {
    requireCorrectSiloBalance();

    require to_mathint(token0.balanceOf(silo0)) >= expectedBalance;
    require to_mathint(silo0._total[ISilo.AssetType.Collateral].assets) >= expectedBalance;
    require to_mathint(shareCollateralToken0.balanceOf(user)) >= expectedBalance;
}

function requireSiloAndUserBalanceWithDebt(mathint expectedBalance, address user) {
    requireCorrectSiloBalance();

    require to_mathint(token0.balanceOf(user)) >= expectedBalance;
    require to_mathint(silo0._total[ISilo.AssetType.Debt].assets) >= expectedBalance;
    require to_mathint(shareDebtToken0.balanceOf(user)) >= expectedBalance;
}

function requireXY(mathint x, mathint y) {
    require x > 1 && x < max_uint128 && y > 1 && y < max_uint128;
}

function diff_1_wei(mathint x, mathint y) returns bool {
    return x > y ? x - y == 1 : y - x == 1;
}