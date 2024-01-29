import "../_common/CommonSummarizations.spec";
import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/VS_Silo_daoAndDeployerFees_and_totals.spec" \
    --msg "fee and totals (quote)" \
    --parametric_contracts Silo0 \
    --method "borrowShares(uint256,address,address)" // to speed up use --method flag
*/
rule VS_Silo_daoAndDeployerFees_and_totals(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 accrueInterestBefore = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 collateralBefore = currentContract.getCollateralAssets();
    uint256 debtBefore = currentContract.getDebtAssets();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();

    uint256 amount;
    address receiver;

    siloFnSelector(e, f, amount, receiver);


    bool accrueInterestIncreased = currentContract.getSiloDataDaoAndDeployerFees() > accrueInterestBefore;
    bool totalCollateralIncreased = currentContract.getCollateralAssets() > collateralBefore;
    bool totalDebtIncreased = currentContract.getCollateralAssets() > debtBefore;

    assert accrueInterestIncreased => totalCollateralIncreased && totalDebtIncreased;

    assert prevTimestamp <= currentContract.getSiloDataInterestRateTimestamp(), "timestamp can only increase";
}
