import "../_common/CommonSummarizations.spec";
import "../_common/CompleteSiloSetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/IsSolventGhost.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";

/**
certoraRun certora/config/silo/completeSilo.conf \
    --parametric_contracts Silo0 \
    --msg "Risk assessment" \
    --verify "Silo0:certora/specs/silo/risk-assessment/RiskAssessment.spec"
*/
rule RA_silo_any_user_can_deposit_borrow(env e) {
    uint256 assets;

    completeSiloSetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    
    uint256 collateralToken0Before = shareCollateralToken0.balanceOf(e.msg.sender);
    silo0.deposit(e, assets, e.msg.sender);
    uint256 collateralToken0After = shareCollateralToken0.balanceOf(e.msg.sender);

    assert collateralToken0Before < collateralToken0After;

    uint256 debtToken1Before = shareDebtToken1.balanceOf(e.msg.sender);
    silo1.borrow(e, assets, e.msg.sender, e.msg.sender);
    uint256 debtToken1After = shareDebtToken1.balanceOf(e.msg.sender);

    assert debtToken1Before < debtToken1After;
}
