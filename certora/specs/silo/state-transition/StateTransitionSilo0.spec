import "../_common/OnlySilo0SetUp.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";

methods {
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => simplified_getCompoundInterestRateAndUpdate(
        _collateralAssets,
        _debtAssets,
        _interestRateTimestamp
    ) expect uint256;
}

function simplified_getCompoundInterestRateAndUpdate(
    uint256 _collateralAssets,
    uint256 _debtAssets,
    uint256 _interestRateTimestamp
) returns uint256 {
    uint256 result;
    // InterestRateModelV2.RCOMP_MAX() == (2**16) * 1e18
    // result >= 1 - to make accrueInterest() work
    require result >= 1 && result <= 2^16 * 10^18;
    return result;
}


/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency 2" \
    --rule "ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency" \
    --verify "Silo0:certora/specs/silo/state-transition/StateTransitionSilo0.spec"
*/
rule ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency(
    env e,
    method f,
    calldataarg args
) filtered { f -> !f.isView} {
    silo0SetUp(e);

    mathint irtBefore = getSiloDataInterestRateTimestamp();
    mathint debtAssetsBefore = silo0._total[ISilo.AssetType.Debt].assets;
    mathint collateralAssetsBefore = silo0._total[ISilo.AssetType.Collateral].assets;

    // to make accrueInterest() work
    require irtBefore < to_mathint(e.block.timestamp);
    require debtAssetsBefore > 10^18 && debtAssetsBefore < max_uint128;
    require collateralAssetsBefore > 10^18 && collateralAssetsBefore < max_uint128;

    f(e, args);

    mathint irtAfter = getSiloDataInterestRateTimestamp();
    mathint debtAssetsAfter = silo0._total[ISilo.AssetType.Debt].assets;

    bool irtChanged = irtBefore != 0 && irtBefore != irtAfter;

    assert irtChanged => debtAssetsAfter != debtAssetsBefore;
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency" \
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
    require debtAssetsBefore < max_uint128;
    require silo0._total[ISilo.AssetType.Collateral].assets < max_uint128;

    f(e, args);

    mathint irtAfter = getSiloDataInterestRateTimestamp();
    mathint debtAssetsAfter = silo0._total[ISilo.AssetType.Debt].assets;
    mathint daoAndDeployerFeesAfter = getSiloDataDaoAndDeployerFees();

    bool irtChanged = irtBefore != 0 && irtBefore != irtAfter;
    bool withFee = daoFee != 0 || deployerFee != 0;

    assert irtChanged && debtAssetsBefore != 0 && withFee => daoAndDeployerFeesBefore <= daoAndDeployerFeesAfter;
}
