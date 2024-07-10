import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/priceOracle.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../_common/SiloFunctionSelector.spec";

methods {
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig,
        ISiloConfig.DebtInfo memory _debtInfo,
        address borrower,
        ISilo.AccrueInterestInMemory accrueInMemory) internal returns (bool) => NONDET;
}

/// DON'T RUN THIS! If you want to prove it, use RiskAssessmentSilo0_ByCertora.spec > RA_more_assets_than_shares
/// Auxiliary invariant (proved elsewhere) - useless with this filter
/// @title The assets of every share token is larger than the total supply of shares (i.e. share price >=1)
invariant RA_more_assets_than_shares() 
    (silo0.total(require_uint256(ISilo.AssetType.Protected)) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(require_uint256(ISilo.AssetType.Collateral)) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(require_uint256(ISilo.AssetType.Debt)) >= shareDebtToken0.totalSupply())
    filtered{f -> f.isView}

/// List of safe assumptions
function SafeAssumptions(env e) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_more_assets_than_shares();
    /// When the Silo timestamp is zero (before first interaction), there are no assets in the pool, thus we can ignore the initial case.
    require silo0.getSiloDataInterestRateTimestamp() > 0;
    require silo1.getSiloDataInterestRateTimestamp() > 0;
}

/// @title Accruing interest (in the same block) should not change the value of any user's shares.
rule PRV_user_assets_invariant_under_accrual_interest_silo0(env e, address user) {
    SafeAssumptions(e);
    uint256 debt_shares_pre = shareDebtToken1.balanceOf(e, user);
    uint256 collateral_shares_pre = shareCollateralToken0.balanceOf(e, user);
    uint256 protected_shares_pre = shareProtectedCollateralToken0.balanceOf(e, user);
    mathint debt_assets_pre = silo0.convertToAssets(e, debt_shares_pre, ISilo.AssetType.Debt);
    mathint collateral_assets_pre = silo0.convertToAssets(e, collateral_shares_pre, ISilo.AssetType.Collateral);
    mathint protected_assets_pre = silo0.convertToAssets(e, protected_shares_pre, ISilo.AssetType.Protected);
        silo0.accrueInterest(e);
    uint256 debt_shares_post = shareDebtToken1.balanceOf(e, user);
    uint256 collateral_shares_post = shareCollateralToken0.balanceOf(e, user);
    uint256 protected_shares_post = shareProtectedCollateralToken0.balanceOf(e, user);
    mathint debt_assets_post = silo0.convertToAssets(e, debt_shares_post, ISilo.AssetType.Debt);
    mathint collateral_assets_post = silo0.convertToAssets(e, collateral_shares_post, ISilo.AssetType.Collateral);
    mathint protected_assets_post = silo0.convertToAssets(e, protected_shares_post, ISilo.AssetType.Protected);

    assert debt_assets_pre == debt_assets_post, "accrual interest cannot change value of debt assets";
    assert collateral_assets_pre == collateral_assets_post, "accrual interest cannot change value of collateral assets";
    assert protected_assets_pre == protected_assets_post, "accrual interest cannot change value of protected assets";
}

/// @title Accruing interest in Silo0 (in the same block) should not change any borrower's LtV.
rule PRV_LtV_invariant_under_accrual_interest_silo0(env e, address borrower) {
    SafeAssumptions(e);
    mathint ltv_before = getLTV(e, borrower);
        silo0.accrueInterest(e);
    mathint ltv_after = getLTV(e, borrower);

    assert ltv_before == ltv_after;
}

/// @title Accruing interest in Silo1 (in the same block) should not change any borrower's LtV.
rule PRV_LtV_invariant_under_accrual_interest_silo1(env e, address borrower) {
    SafeAssumptions(e);
    mathint ltv_before = getLTV(e, borrower);
        silo1.accrueInterest(e);
    mathint ltv_after = getLTV(e, borrower);

    assert ltv_before == ltv_after;
}
