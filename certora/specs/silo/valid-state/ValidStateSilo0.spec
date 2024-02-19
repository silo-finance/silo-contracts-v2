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
    --msg "VS_Silo_totals_share_token_totalSupply" \
    --rule "VS_Silo_totals_share_token_totalSupply" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_totals_share_token_totalSupply(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    require shareCollateralToken0.totalSupply() == 0;
    require shareProtectedCollateralToken0.totalSupply() == 0;
    require shareDebtToken0.totalSupply() == 0;

    require silo0.total(ISilo.AssetType.Collateral) == 0;
    require silo0.total(ISilo.AssetType.Protected) == 0;
    require silo0.total(ISilo.AssetType.Debt) == 0;

    f(e, args);

    assert silo0.total(ISilo.AssetType.Collateral) == 0 <=> shareCollateralToken0.totalSupply() == 0,
        "Collateral total supply 0 <=> silo collateral assets 0";

    assert silo0.total(ISilo.AssetType.Protected) == 0 <=> shareProtectedCollateralToken0.totalSupply() == 0,
        "Protected total supply 0 <=> silo protected assets 0";

    assert silo0.total(ISilo.AssetType.Debt) == 0 <=> shareDebtToken0.totalSupply() == 0,
        "Debt total supply 0 <=> silo debt assets 0";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_interestRateTimestamp_daoAndDeployerFees" \
    --rule "VS_Silo_interestRateTimestamp_daoAndDeployerFees" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_interestRateTimestamp_daoAndDeployerFees(
    env e,
    method f,
    calldataarg args
) filtered { f -> !f.isView && f.selector != flashLoanSig()} {
    silo0SetUp(e);

    require getSiloDataInterestRateTimestamp() == 0;
    require getSiloDataDaoAndDeployerFees() == 0;

    f(e, args);

    mathint feesAfter = getSiloDataDaoAndDeployerFees();

    assert getSiloDataInterestRateTimestamp() == 0 => feesAfter == 0,
        "Interest rate timestamp 0 => dao and deployer fees 0";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_totalBorrowAmount" \
    --rule "VS_Silo_totalBorrowAmount" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_totalBorrowAmount(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);

    require silo0.total(ISilo.AssetType.Collateral) == 0;
    require silo0.total(ISilo.AssetType.Debt) == 0;

    f(e, args);

    assert silo0.total(ISilo.AssetType.Debt) != 0 => silo0.total(ISilo.AssetType.Collateral) != 0,
        "Total debt assets != 0 => total collateral assets != 0";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_silo_getLiquidity_less_equal_balance" \
    --rule "VS_silo_getLiquidity_less_equal_balance" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_silo_getLiquidity_less_equal_balance(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCorrectSiloBalance();

    f(e, args);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint siloBalanceAfter = token0.balanceOf(silo0);
    mathint liquidityAfter = silo0.getLiquidity();

    assert liquidityAfter <= siloBalanceAfter - protectedAssetsAfter,
        "Available liquidity should not be higher than the balance of the silo without protected assets";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_balance_totalAssets" \
    --rule "VS_Silo_balance_totalAssets" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_balance_totalAssets(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCorrectSiloBalance();

    f(e, args);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    assert siloBalanceAfter >= protectedAssetsAfter,
        "Silo balance should be greater than or equal to the total protected assets";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_debtShareToken_balance_notZero" \
    --rule "VS_Silo_debtShareToken_balance_notZero" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_debtShareToken_balance_notZero(env e, method f, address receiver) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint debtBalanceBefore = shareDebtToken0.balanceOf(receiver);
    require debtBalanceBefore == 0;

    siloFnSelectorWithReceiver(e, f, receiver);

    mathint debtBalanceAfter = shareDebtToken0.balanceOf(receiver);
    mathint collateralBalanceAfter = shareCollateralToken0.balanceOf(receiver);
    mathint protectedBalanceAfter = shareProtectedCollateralToken0.balanceOf(receiver);

    assert debtBalanceAfter != 0 => (collateralBalanceAfter + protectedBalanceAfter) == 0,
        "Debt balance != 0 => collateral balance + protected balance == 0";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_shareToken_supply_totalAssets_debt" \
    --rule "VS_Silo_shareToken_supply_totalAssets_debt" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_shareToken_supply_totalAssets_debt(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireDebtToken0TotalAndBalancesIntegrity();

    require shareDebtToken0.totalSupply() == 0;
    require silo0.total(ISilo.AssetType.Debt) == 0;

    f(e, args);

    mathint totalSupplyAfter = shareDebtToken0.totalSupply();

    assert totalSupplyAfter != 0 => totalSupplyAfter <= to_mathint(silo0.total(ISilo.AssetType.Debt)),
        "Debt total supply != 0 => total supply <= total debt assets";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_shareToken_supply_totalAssets_collateral" \
    --rule "VS_Silo_shareToken_supply_totalAssets_collateral" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_shareToken_supply_totalAssets_collateral(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();

    require shareCollateralToken0.totalSupply() == 0;
    require silo0.total(ISilo.AssetType.Collateral) == 0;

    f(e, args);

    mathint totalSupplyAfter = shareCollateralToken0.totalSupply();

    assert totalSupplyAfter != 0 => totalSupplyAfter <= to_mathint(silo0.total(ISilo.AssetType.Collateral)),
        "Collateral total supply != 0 => total supply <= total collateral assets";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_shareToken_supply_totalAssets_protected" \
    --rule "VS_Silo_shareToken_supply_totalAssets_protected" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
rule VS_Silo_shareToken_supply_totalAssets_protected(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireProtectedToken0TotalAndBalancesIntegrity();

    require shareProtectedCollateralToken0.totalSupply() == 0;
    require silo0.total(ISilo.AssetType.Protected) == 0;

    f(e, args);

    mathint totalSupplyAfter = shareProtectedCollateralToken0.totalSupply();

    assert totalSupplyAfter != 0 => totalSupplyAfter <= to_mathint(silo0.total(ISilo.AssetType.Protected)),
        "Protected total supply != 0 => total supply <= total protected assets";
}
