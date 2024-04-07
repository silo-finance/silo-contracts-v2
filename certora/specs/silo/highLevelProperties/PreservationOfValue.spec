import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/priceOracle.spec";
import "../../_simplifications/SiloMathLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

methods {
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig,
        address borrower,
        ISilo.AccrueInterestInMemory accrueInMemory,
        uint256 debtShareBalance
    ) internal returns (bool) => NONDET;
}

definition abs(mathint x, mathint y) returns mathint = x > y ? x - y : y - x;

definition MINIMUM_SHARES() returns uint256 = 10^6; //0
definition MINIMUM_ASSETS() returns uint256 = 10^6; //0

/// Assume minimal value for the shares tokens supply.
function setMinimumSharesTotalSupply(uint256 min_value) {
    require
        shareCollateralToken0.totalSupply() >= min_value &&
        shareProtectedCollateralToken0.totalSupply() >= min_value &&
        shareDebtToken0.totalSupply() >= min_value;
}

/// Auxiliary invariant (proved elsewhere) - 
/// @title The assets of every share token is larger than the total supply of shares (i.e. share price >=1)
invariant RA_more_assets_than_shares() 
    (silo0.total(ISilo.AssetType.Protected) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Collateral) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Debt) >= shareDebtToken0.totalSupply())
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

/// @title maxWithdraw() of asset type is independent of withdraw action of any other asset.
rule PRV_maxWithdraw_collateral_assets_independence(env e, address user) {
    SafeAssumptions(e);
    require e.block.timestamp < 2^64;
    ISilo.AssetType typeA;
    ISilo.AssetType typeB;
    require typeA != typeB;

    mathint maxAssets_before = maxWithdraw(e, user, typeA);
        uint256 assets;
        address receiver;
        address owner;
        withdraw(e, assets, receiver, owner, typeB);
    mathint maxAssets_after = maxWithdraw(e, user, typeA);

    assert abs(maxAssets_before, maxAssets_after) <= 2;
} 

/// @title Redeeming shares preserves the sum of the user shares value and underlying tokens balance.
rule PRV_redeem_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    require owner != silo0;
    setMinimumSharesTotalSupply(MINIMUM_SHARES());

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
    /// Sum of tokens should be bounded.
    require assets_before + tokens_before <= max_uint256;
        uint256 shares;
        redeem(e, shares, owner, owner, ISilo.AssetType.Collateral);
    uint256 shares_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_after = token0.balanceOf(e, owner);
    uint256 assets_after = silo0.convertToAssets(e, shares_after);

    mathint tokens_gain = tokens_after - tokens_before;
    mathint assets_redeemed = assets_before - assets_after;
    assert abs(tokens_gain, assets_redeemed) <= 2;
}

/// @title Withdrawing assets preserves the sum of the user shares value and underlying tokens balance.
rule PRV_withdraw_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    require owner != silo0;

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
    /// Sum of tokens should be bounded.
    require tokens_before + assets_before <= max_uint256;
        uint256 assets;
        require assets >= MINIMUM_ASSETS();
        withdraw(e, assets, owner, owner, ISilo.AssetType.Collateral);
    uint256 shares_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_after = token0.balanceOf(e, owner);
    uint256 assets_after = silo0.convertToAssets(e, shares_after);

    mathint tokens_gain = tokens_after - tokens_before;
    mathint assets_redeemed = assets_before - assets_after;
    assert abs(tokens_gain, assets_redeemed) <= 2;
}

/// @title Depositing assets preserves the sum of the user shares value and underlying tokens balance.
rule PRV_deposit_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    require owner != silo0;
    setMinimumSharesTotalSupply(MINIMUM_SHARES());

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
    require tokens_before + totalAssets(e) <= max_uint256;
        uint256 assets;
        deposit(e, assets, owner, ISilo.AssetType.Collateral);
    uint256 shares_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_after = token0.balanceOf(e, owner);
    uint256 assets_after = silo0.convertToAssets(e, shares_after);

    mathint tokens_loss = tokens_before - tokens_after;
    mathint assets_deposited = assets_after - assets_before;
    assert abs(tokens_loss, assets_deposited) <= 2;
}

/// @title Transitioning collateral preserves the sum of the user shares value and underlying tokens balance.
rule PRV_transition_collateral_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    setMinimumSharesTotalSupply(MINIMUM_SHARES());

    uint256 sharesC_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_before = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_before = silo0.convertToAssets(e, sharesC_before, ISilo.AssetType.Collateral);
    uint256 assetsP_before = silo0.convertToAssets(e, sharesP_before, ISilo.AssetType.Protected);
    /// Sum of assets should be bounded.
    require assetsP_before + assetsC_before + token0.balanceOf(e, silo0) <= max_uint256;
        uint256 shares;
        transitionCollateral(e, shares, owner, ISilo.AssetType.Collateral);
    uint256 sharesC_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_after = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_after = silo0.convertToAssets(e, sharesC_after, ISilo.AssetType.Collateral);
    uint256 assetsP_after = silo0.convertToAssets(e, sharesP_after, ISilo.AssetType.Protected); 

    /// Technically, each operation (deposit, withdraw) should have a maximal error of 2, so overall 4. 
    assert abs(assetsP_after + assetsC_after, assetsP_before + assetsC_before) <= 4;
}

/// @title Transitioning (protected) collateral preserves the sum of the user shares value and underlying tokens balance.
rule PRV_transition_protected_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    setMinimumSharesTotalSupply(MINIMUM_SHARES());

    uint256 sharesC_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_before = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_before = silo0.convertToAssets(e, sharesC_before, ISilo.AssetType.Collateral);
    uint256 assetsP_before = silo0.convertToAssets(e, sharesP_before, ISilo.AssetType.Protected);
    require assetsP_before + assetsC_before + token0.balanceOf(e, silo0) <= max_uint256;
        uint256 shares;
        transitionCollateral(e, shares, owner, ISilo.AssetType.Protected);
    uint256 sharesC_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_after = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_after = silo0.convertToAssets(e, sharesC_after, ISilo.AssetType.Collateral);
    uint256 assetsP_after = silo0.convertToAssets(e, sharesP_after, ISilo.AssetType.Protected); 

    assert abs(assetsP_after + assetsC_after, assetsP_before + assetsC_before) <= 4;
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
/// Verified (Difficult)
rule PRV_LtV_invariant_under_accrual_interest_silo0(env e, address borrower) {
    SafeAssumptions(e);
    mathint ltv_before = getLTV(e, borrower);
        silo0.accrueInterest(e);
    mathint ltv_after = getLTV(e, borrower);

    assert ltv_before == ltv_after;
}

/// @title Accruing interest in Silo1 (in the same block) should not change any borrower's LtV.
/// Verified (Difficult)
rule PRV_LtV_invariant_under_accrual_interest_silo1(env e, address borrower) {
    SafeAssumptions(e);
    mathint ltv_before = getLTV(e, borrower);
        silo1.accrueInterest(e);
    mathint ltv_after = getLTV(e, borrower);

    assert ltv_before == ltv_after;
}

/// @title Accruing interest in Silo0 (in the same block) should not change the protocol accrued fees.
/// Violated
rule PRV_DAO_fees_invariant_under_accrual_interest_silo0(env e) {
    SafeAssumptions(e);
    mathint fees_before = getSiloDataDaoAndDeployerFees(e);
        silo0.accrueInterest(e);
    mathint fees_after = getSiloDataDaoAndDeployerFees(e);

    assert fees_before == fees_after;
}

/// @title Accruing interest in Silo1 (in the same block) should not change any borrower's LtV.
rule PRV_DAO_fees_invariant_under_accrual_interest_silo1(env e) {
    SafeAssumptions(e);
    mathint fees_before = getSiloDataDaoAndDeployerFees(e);
        silo1.accrueInterest(e);
    mathint fees_after = getSiloDataDaoAndDeployerFees(e);

    assert fees_before == fees_after;
}