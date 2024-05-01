import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/priceOracle.spec";
import "../../_simplifications/SiloMathLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../_common/SiloFunctionSelector.spec";

definition abs(mathint x, mathint y) returns mathint = x > y ? x - y : y - x;

definition MINIMUM_SHARES() returns uint256 = 10^6; //0
definition MINIMUM_ASSETS() returns uint256 = 10^6; //0

/// Auxiliary invariant (proved elsewhere) - 
/// @title The assets of every share token is larger than the total supply of shares (i.e. share price >=1)
invariant RA_more_assets_than_shares() 
    (silo0.total(ISilo.AssetType.Protected) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Collateral) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Debt) >= shareDebtToken0.totalSupply())
    filtered{f -> f.isView}

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

/*
==================================================================
Rules with rounding errors violations
==================================================================
*/

rule PRV_function_preserves_user_value(env e, method f) filtered{f -> 
    f.selector == withdrawWithTypeSig() ||
    f.selector == depositWithTypeSig() ||
    f.selector == redeemWithTypeSig() ||
    f.selector == transitionCollateralSig()
} {
    SafeAssumptions(e);
    address owner = e.msg.sender;
    require owner != silo0;

    uint256 assetsOrShares;
    uint256 ownerBalance = token0.balanceOf(e, owner);
    require getCollateralAssets(e) + ownerBalance <= max_uint256; 
    setMinimumSharesTotalSupply(MINIMUM_SHARES());

    uint256 shares_before = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_before = token0.balanceOf(e, owner);
    uint256 assets_before = silo0.convertToAssets(e, shares_before);
        siloFnSelector(e, f, assetsOrShares, owner, owner, ISilo.AssetType.Collateral);
    uint256 shares_after = shareCollateralToken0.balanceOf(e, owner);
    uint256 tokens_after = token0.balanceOf(e, owner);
    uint256 assets_after = silo0.convertToAssets(e, shares_after);

    mathint tokens_gain = tokens_after - tokens_before;
    mathint assets_redeemed = assets_before - assets_after;
    assert abs(tokens_gain, assets_redeemed) <= 2;
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

/// @title Repaying cannot turn a user to insolvent.
rule RA_silo_solvent_after_repaying(env e, address borrower) {
    SafeAssumptions(e);

    require isSolvent(e, borrower);
        uint256 assets;
        repay(e, assets, borrower);
    assert isSolvent(e, borrower);
}

/// @title A borrower must be solvent after borrowing.
rule RA_silo_solvent_after_borrow(env e, address borrower) {
    SafeAssumptions(e);
    
    uint256 assets;
    address receiver;
    borrow(e, assets, receiver, borrower);
    assert isSolvent(e, borrower);
}

/// @title deposit() preserves the user's solvency.
rule RA_silo_solvent_after_deposit(env e, address borrower) {
    SafeAssumptions(e);
    
    uint256 assets;
    address receiver;
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;
    require isSolvent(e, borrower);
        deposit(e, assets, receiver);
    assert isSolvent(e, borrower);
}

/// @title If there is no collateral in the system, there couldn't be any debt.
invariant RA_no_collateral_assets_no_debt_assets()
    silo0.total(ISilo.AssetType.Collateral) ==0 &&
    silo0.total(ISilo.AssetType.Protected) ==0 =>
    (   
        /// Liquidity constraint
        silo0.total(ISilo.AssetType.Debt) ==0 
        &&
        /// Solvency constraint
        silo1.total(ISilo.AssetType.Debt) ==0
    )
    {
        preserved with (env e) {
            SafeAssumptions(e);
            require isSolvent(e, e.msg.sender);
        }
    }

/// @title For any asset type, the total assets is zero iff the shares total supply is zero.
invariant RA_zero_assets_iff_zero_shares() 
    (silo0.total(ISilo.AssetType.Protected) ==0 <=> shareProtectedCollateralToken0.totalSupply() == 0) &&
    (silo0.total(ISilo.AssetType.Collateral) ==0 <=> shareCollateralToken0.totalSupply() == 0) &&
    (silo0.total(ISilo.AssetType.Debt) ==0 <=> shareDebtToken0.totalSupply() == 0) 
    {
        preserved with (env e) {
            completeSiloSetupEnv(e);
            totalSupplyMoreThanBalance(e.msg.sender);
            requireInvariant RA_no_collateral_assets_no_debt_assets();
        }
    }

/// @title User should not be able to borrow more than maxBorrow().
/// Violated (but not a real issue - maxBorrow() could under-estimate)
rule RA_silo_cant_borrow_more_than_max(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);

    uint256 maxAssets = maxBorrow(e, borrower);
    uint256 assets; address receiver; 
    borrow(e, assets, receiver, borrower);

    assert assets <= maxAssets;
}