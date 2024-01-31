import "../_common/CommonSummarizations.spec";
import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/MulDiv_simplification.spec";
import "../../_simplifications/Sqrt_simplification.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/VS_Silo_daoAndDeployerFees_and_totals.spec" \
    --msg "fee and totals (V8)" \
    --parametric_contracts Silo0 \
    --method "accrueInterest()" // to speed up use --method flag
*/
rule VS_Silo_daoAndDeployerFees_and_totals(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 feesBefore = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 collateralBefore = currentContract.getCollateralAssets();
    uint256 debtBefore = currentContract.getDebtAssets();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();

    uint256 daoFee = currentContract.getDaoFee();
    uint256 deployerFee = currentContract.getDeployerFee();

    uint256 amount;
    address receiver;

    siloFnSelector(e, f, amount, receiver);

    uint256 feesAfter = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 collateralAfter = currentContract.getCollateralAssets();

    mathint feesDiff = currentContract.getSiloDataDaoAndDeployerFees() - feesBefore;
    bool feesIncreased = feesDiff > 0;

    assert f.selector == withdrawFeesSig() => feesDiff < 0, "fees withdrawn";

    assert feesIncreased => feesDiff <= currentContract.getDebtAssets() - debtBefore, "interest must be cover by debt";

    bool totalDebtIncreased = currentContract.getDebtAssets() > debtBefore;
    bool totalCollateralIncreased = currentContract.getCollateralAssets() > collateralBefore;

    uint256 hundredPercent = 10 ^ 18;

    if (debtBefore == 0) {
        assert !feesIncreased, "without debt there is no interest/fees";
    } else if (feesDiff == 1 && (daoFee + deployerFee) > 0) {
        assert !totalCollateralIncreased && totalDebtIncreased, "with just 1 interest, all goes to dao and deployer";
    } else {
        assert feesIncreased => totalCollateralIncreased && totalDebtIncreased;
    }

    assert prevTimestamp <= currentContract.getSiloDataInterestRateTimestamp(), "timestamp can only increase";
}
