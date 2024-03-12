import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

rule remainsSolventAfterSelfLiquidation(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    mathint debtBefore = shareDebtToken0.balanceOf(user);
    mathint balanceCollateralOtherSiloBefore = shareCollateralToken1.balanceOf(user);

    //require isSolvent(user);
    require debtBefore > 10^20 && balanceCollateralOtherSiloBefore > 10^20;
    uint256 _debtToCover;
    bool _receiveSToken;
    liquidationCall(e, token1, token0, user, _debtToCover, _receiveSToken);
    satisfy true;
    
    mathint debtAfter = shareDebtToken0.balanceOf(user);
    mathint balanceCollateralOtherSiloAfter = shareCollateralToken1.balanceOf(user);

    assert debtAfter > 10^5 => balanceCollateralOtherSiloAfter > 0;
 
}