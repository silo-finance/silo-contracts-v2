import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/PriceIsOne.spec";
import "../_common/IsSolventGhost.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";
import "../_common/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../_common/CommonSummarizations.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "Viriables change Silo0" \
    --method "withdraw(uint256,address,address)" \
    --rule "VC_Silo_total_collateral_increase" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"

to verify the particular function add:
--method "deposit(uint256,address)"

    --method "withdraw(uint256,address,address)" \

to run the particular rule add:
--rule "VC_Silo_total_collateral_increase"
*/
rule VC_Silo_total_collateral_increase(
    env e,
    method f,
    uint256 assets
)
    filtered { f -> !f.isView && !f.isFallback }
{
    silo0SetUp(e);

    require assets >= 3;

    mathint totalDepositsBefore = getCollateralAssets();
    mathint shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelectorWithAssets(e, f, assets);

    mathint totalDepositsAfter = getCollateralAssets();
    mathint shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    assert totalDepositsBefore < totalDepositsAfter && shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter =>
        (f.selector == depositSig() || f.selector == mintSig()) &&
        siloBalanceBefore + assets == siloBalanceAfter &&
        (
            (!withInterest && totalDepositsBefore + assets == totalDepositsAfter) ||
            // with an interest it should be bigger or the same
            (withInterest && totalDepositsBefore + assets <= totalDepositsAfter)
        ),
        "Deposit and mint fn should increase total deposits and silo balance";

    assert f.selector == accrueInterestSig() && withInterest =>
         totalDepositsBefore <= totalDepositsAfter && // it may be the same if the interest is 0
         shareTokenTotalSupplyBefore == shareTokenTotalSupplyAfter,
        "AccrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets";
}
