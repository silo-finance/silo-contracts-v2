import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "Variables change Silo0" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"

to verify the particular function add:
--method "deposit(uint256,address)"

to run the particular rule add:
--rule "VC_Silo_totalDeposits_change_on_Deposit"
*/
rule VC_Silo_totalDeposits_change_on_Deposit(
    env e,
    method f,
    address receiver,
    uint256 assets
)
    filtered { f -> !f.isView && !f.isFallback }
{
    silo0SetUp(e);
    disableAccrueInterest(e);

    require receiver == e.msg.sender;

    uint256 totalDepositsBefore = getCollateralAssets();
    uint256 shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    uint256 shareTokenBalanceBefore = shareCollateralToken0.balanceOf(e.msg.sender);

    require shareTokenBalanceBefore <= shareTokenTotalSupplyBefore;

    siloFnSelector(e, f, assets, receiver);

    uint256 totalDepositsAfter = getCollateralAssets();
    uint256 shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    uint256 shareTokenBalanceAfter = shareCollateralToken0.balanceOf(e.msg.sender);

    assert f.selector == depositSig() =>
        totalDepositsBefore < totalDepositsAfter &&
        shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter &&
        shareTokenBalanceBefore < shareTokenBalanceAfter,
        "deposit fn should increase total deposits and balance";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_collateral_increase" \
    --method "mint(uint256,address)" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_collateral_increase(env e, method f, uint256 assetsOrShares, address receiver) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint totalDepositsBefore = getCollateralAssets();
    mathint shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint totalDepositsAfter = getCollateralAssets();
    mathint shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool isDeposit =  f.selector == depositSig() || f.selector == depositWithTypeSig();
    bool isMint = f.selector == mintSig() || f.selector == mintWithTypeSig();

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    mathint expectedBalance = siloBalanceBefore + assetsOrShares;
    mathint expectedTotalDeposits = totalDepositsBefore + assetsOrShares;

    assert totalSupplyIncreased => totalDepositsBefore < totalDepositsAfter,
        "Total deposits should increase if total supply of share tokens increased";

    assert totalSupplyIncreased => isDeposit || isMint,
        "Total supply of share tokens should increase only if deposit or mint fn was called";

    assert totalSupplyIncreased && isDeposit => expectedBalance == siloBalanceAfter &&
        (
            (!withInterest && expectedTotalDeposits == totalDepositsAfter) ||
            // with an interest it should be bigger or the same
            (withInterest && expectedTotalDeposits <= totalDepositsAfter)
        ),
        "Deposit and mint fn should increase total deposits and silo balance";

    mathint expectedSharesBalance = balanceSharesBefore + assetsOrShares;

    assert totalSupplyIncreased && isMint =>
        expectedSharesBalance - 1 == balanceSharesAfter || expectedSharesBalance == balanceSharesAfter,
        "Mint fn should increase balance of share tokens";

    assert f.selector == accrueInterestSig() && withInterest =>
         totalDepositsBefore <= totalDepositsAfter && // it may be the same if the interest is 0
         shareTokenTotalSupplyBefore == shareTokenTotalSupplyAfter,
        "AccrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets";
}