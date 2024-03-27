import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/priceOracle.spec";
import "../../_simplifications/SiloSolvencyLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

definition abs(mathint x, mathint y) returns mathint = x > y ? x - y : y - x;

invariant RA_more_assets_than_shares() 
    (silo0.total(ISilo.AssetType.Protected) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Collateral) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Debt) >= shareDebtToken0.totalSupply());

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
    require silo0.getSiloDataInterestRateTimestamp() > 0;
}

rule PRV_redeem_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    require owner != silo0;

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
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

rule PRV_withdraw_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    require owner != silo0;

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
    require tokens_before + assets_before <= max_uint256;
        uint256 assets;
        withdraw(e, assets, owner, owner, ISilo.AssetType.Collateral);
    uint256 shares_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_after = token0.balanceOf(e, owner);
    uint256 assets_after = silo0.convertToAssets(e, shares_after);

    mathint tokens_gain = tokens_after - tokens_before;
    mathint assets_redeemed = assets_before - assets_after;
    assert abs(tokens_gain, assets_redeemed) <= 2;
}

rule PRV_deposit_preserves_value(env e, address owner) {
    SafeAssumptions(e);
    require owner != silo0;

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

rule PRV_transition_collateral_preserves_value(env e, address owner) {
    SafeAssumptions(e);

    uint256 sharesC_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_before = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_before = silo0.convertToAssets(e, sharesC_before, ISilo.AssetType.Collateral);
    uint256 assetsP_before = silo0.convertToAssets(e, sharesP_before, ISilo.AssetType.Protected);
    require assetsP_before + assetsC_before + token0.balanceOf(e, silo0) <= max_uint256;
        uint256 shares;
        transitionCollateral(e, shares, owner, ISilo.AssetType.Collateral);
    uint256 sharesC_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 sharesP_after = shareProtectedCollateralToken0.balanceOf(e, owner);
    uint256 assetsC_after = silo0.convertToAssets(e, sharesC_after, ISilo.AssetType.Collateral);
    uint256 assetsP_after = silo0.convertToAssets(e, sharesP_after, ISilo.AssetType.Protected); 

    assert assetsP_after + assetsC_after == assetsP_before + assetsC_before;
}

rule PRV_transition_protected_preserves_value(env e, address owner) {
    SafeAssumptions(e);

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

    assert assetsP_after + assetsC_after == assetsP_before + assetsC_before;
}