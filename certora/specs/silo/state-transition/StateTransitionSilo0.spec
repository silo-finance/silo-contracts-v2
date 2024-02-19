import "../_common/OnlySilo0SetUp.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency" \
    --rule "ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency" \
    --verify "Silo0:certora/specs/silo/state-transition/StateTransitionSilo0.spec"
*/
rule ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency(
    env e,
    method f,
    uint256 assetsOrShare
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint irtBefore = getSiloDataInterestRateTimestamp();
    mathint debtAssetsBefore = silo0._total[ISilo.AssetType.Debt].assets;

    require irtBefore < to_mathint(e.block.timestamp);

    mathint accruedInterest = accrueInterest(e);

    // to avoid repaying the same amount as accrued interest
    if (f.selector == repaySig()) {
        require to_mathint(assetsOrShare) != accruedInterest;
    } else if (f.selector == repaySharesSig()) {
        mathint shareDebtTokenTotal = shareDebtToken0.totalSupply();
        mathint debtAssetsWithInterest = silo0._total[ISilo.AssetType.Debt].assets;

        require toAssetsRoundUpLike(assetsOrShare, debtAssetsWithInterest, shareDebtTokenTotal) != accruedInterest;
    }

    siloFnSelectorWithAssets(e, f, assetsOrShare);

    mathint irtAfter = getSiloDataInterestRateTimestamp();
    mathint debtAssetsAfter = silo0._total[ISilo.AssetType.Debt].assets;

    bool irtChanged = irtBefore != 0 && irtBefore != irtAfter;

    assert irtChanged && accruedInterest != 0 => debtAssetsAfter != debtAssetsBefore;
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency 2" \
    --rule "ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency" \
    --verify "Silo0:certora/specs/silo/state-transition/StateTransitionSilo0.spec"
*/
rule ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency(
    env e,
    method f,
    calldataarg args
) filtered { f -> !f.isView} {
    silo0SetUp(e);

    mathint irtBefore = getSiloDataInterestRateTimestamp();
    mathint debtAssetsBefore = silo0._total[ISilo.AssetType.Debt].assets;
    mathint daoFee = getDaoFee();
    mathint deployerFee = getDeployerFee();
    mathint daoAndDeployerFeesBefore = getSiloDataDaoAndDeployerFees();

    require daoAndDeployerFeesBefore < max_uint128;

    f(e, args);

    mathint irtAfter = getSiloDataInterestRateTimestamp();
    mathint debtAssetsAfter = silo0._total[ISilo.AssetType.Debt].assets;
    mathint daoAndDeployerFeesAfter = getSiloDataDaoAndDeployerFees();

    bool irtChanged = irtBefore != 0 && irtBefore != irtAfter;
    bool withFee = daoFee != 0 || deployerFee != 0;

    assert irtChanged && debtAssetsBefore != 0 && withFee => daoAndDeployerFeesBefore <= daoAndDeployerFeesAfter;
}
