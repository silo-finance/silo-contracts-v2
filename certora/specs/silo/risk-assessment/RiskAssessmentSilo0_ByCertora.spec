import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

// A user cannot withdraw anything after withdrawing whole balance.
// holds
// https://prover.certora.com/output/6893/6ebdfe9df3f04b4b887bdb1c5372637c/?anonymousKey=af1886c64a28e05f1ee50a3c98745a75596a38ad
rule RA_Silo_no_withdraw_after_withdrawing_all(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    

    uint256 balanceCollateralBefore = shareCollateralToken0.balanceOf(user);
    uint256 balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(user);

    storage init = lastStorage;
    mathint assets = redeem(e, balanceCollateralBefore, user, user, ISilo.AssetType.Collateral);
    uint256 shares;
    redeem@withrevert(e, shares, user, user, ISilo.AssetType.Collateral);
    assert lastReverted;

    mathint assets2 = redeem(e, balanceProtectedCollateralBefore, user, user, ISilo.AssetType.Protected) at init;
    uint256 shares2;
    redeem@withrevert(e, shares2, user, user, ISilo.AssetType.Protected);
    assert lastReverted;

}

