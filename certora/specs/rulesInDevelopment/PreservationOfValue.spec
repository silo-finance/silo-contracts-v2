import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/priceOracle.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../_common/SiloFunctionSelector.spec";

// These are in development. Might not be 100% correct, might give spurious CEXs, etc.
// Some of these rules might overlap with methods' integrity rules

methods {
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig,
        ISiloConfig.DebtInfo memory _debtInfo,
        address borrower,
        ISilo.AccrueInterestInMemory accrueInMemory) internal returns (bool) => NONDET;
}

definition abs(mathint x, mathint y) returns mathint = x > y ? x - y : y - x;

definition MINIMUM_SHARES() returns uint256 = 10^6; //0
definition MINIMUM_ASSETS() returns uint256 = 10^6; //0

/// Assume minimal value for the shares tokens supply.
function setMinimumSharesTotalSupply(uint256 min_value) {
    uint256 supply_collateral = shareCollateralToken0.totalSupply();
    uint256 supply_protected = shareProtectedCollateralToken0.totalSupply();
    uint256 supply_debt = shareDebtToken0.totalSupply();
    
    require
        (supply_collateral >= min_value || supply_collateral == 0) &&
        (supply_protected >= min_value || supply_protected == 0) &&
        (supply_debt >= min_value || supply_debt == 0);
}

function getPriceOfToken0At(env e, address oracle) returns uint256 {
    return priceOracle(oracle, token0, e.block.timestamp);
}

function getPriceOfToken1At(env e, address oracle) returns uint256 {
    return priceOracle(oracle, token1, e.block.timestamp);
}

/// DONT RUN THIS! If you want to prove it, use RiskAssessmentSilo0_ByCertora.spec > RA_more_assets_than_shares
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

/// @title maxWithdraw() of asset type is independent of withdraw action of any other asset.
rule PRV_maxWithdraw_collateral_assets_independence(env e, address user) {
    SafeAssumptions(e);
    ISilo.CollateralType typeA;
    ISilo.CollateralType typeB;
    require typeA != typeB;

    mathint maxAssets_before = maxWithdraw(e, user);
        uint256 assets;
        address receiver;
        address owner;
        withdraw(e, assets, receiver, owner, typeB);
    mathint maxAssets_after = maxWithdraw(e, user);

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
        redeem(e, shares, owner, owner, ISilo.CollateralType.Collateral);
    uint256 shares_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_after = token0.balanceOf(e, owner);
    uint256 assets_after = silo0.convertToAssets(e, shares_after);

    mathint tokens_gain = tokens_after - tokens_before;
    mathint assets_redeemed = assets_before - assets_after;
    assert abs(tokens_gain, assets_redeemed) <= 2;
}

rule PRV_function_preserves_user_value(env e, method f) filtered{f -> 
    f.selector == withdrawWithTypeSig() ||
    f.selector == depositWithTypeSig() ||
    f.selector == redeemWithTypeSig() ||
    f.selector == transitionCollateralSig()
} {
    SafeAssumptions(e);
    address owner = e.msg.sender;
    require owner != silo0;

    bool sameAsset;

    uint256 assetsOrShares;
    uint256 ownerBalance = token0.balanceOf(e, owner);
    require getCollateralAssets(e) + ownerBalance <= max_uint256; 
    setMinimumSharesTotalSupply(MINIMUM_SHARES());

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
        siloFnSelector(e, f, assetsOrShares, owner, owner, sameAsset, ISilo.CollateralType.Collateral);
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
        withdraw(e, assets, owner, owner, ISilo.CollateralType.Collateral);
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
        deposit(e, assets, owner, ISilo.CollateralType.Collateral);
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
        transitionCollateral(e, shares, owner, ISilo.CollateralType.Collateral);
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
        transitionCollateral(e, shares, owner, ISilo.CollateralType.Protected);
    uint256 sharesC_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_after = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_after = silo0.convertToAssets(e, sharesC_after, ISilo.AssetType.Collateral);
    uint256 assetsP_after = silo0.convertToAssets(e, sharesP_after, ISilo.AssetType.Protected); 

    assert abs(assetsP_after + assetsC_after, assetsP_before + assetsC_before) <= 4;
}


/// @title LTV increases with time
rule PRV_LtV_increases_with_time(env e1, address borrower) {
    SafeAssumptions(e1);
    env e2;
    require e2.block.timestamp >= e1.block.timestamp;
    require e2.block.timestamp < (1 << 64);

    /// Assuming the last timestamp corresponds to the first env.
    require silo0.getSiloDataInterestRateTimestamp() == e1.block.timestamp;
    mathint ltv1 = getLTV(e1, borrower);
    mathint ltv2 = getLTV(e2, borrower);

    /// If the prices between two timestamps do not change, then the ltV cannot decrease.
    assert ( 
        getPriceOfToken0At(e1, maxLtvOracle0) == getPriceOfToken0At(e2, maxLtvOracle0) &&
        getPriceOfToken1At(e1, maxLtvOracle1) == getPriceOfToken1At(e2, maxLtvOracle1)
    ) => ltv1 <= ltv2;

    satisfy ltv1 < ltv2;
}

/// @title Accruing interest in Silo0 (in the same block) should not change the protocol accrued fees.
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

/// @title Fees interest must increase in time.
rule PRV_fees_increases_with_time(env e1) {
    SafeAssumptions(e1);
    env e2;
    require e2.block.timestamp >= e1.block.timestamp;
    require e2.block.timestamp < (1 << 64);

    mathint fees1 = getSiloDataDaoAndDeployerFees(e1);
    mathint fees2 = getSiloDataDaoAndDeployerFees(e2);

    assert fees1 <= fees2;
    satisfy fees1 < fees2;
}