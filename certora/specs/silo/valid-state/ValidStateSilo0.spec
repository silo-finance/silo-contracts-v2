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
    --msg "VS_Silo_totals_share_token_totalSupply" \
    --rule "VS_Silo_totals_share_token_totalSupply" \
    --verify "Silo0:certora/specs/silo/variable-changes/ValidStateSilo0.spec"
*/
rule VS_Silo_totals_share_token_totalSupply(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    require shareCollateralToken0.totalSupply() == 0;
    require shareProtectedCollateralToken0.totalSupply() == 0;
    require shareDebtToken0.totalSupply() == 0;

    require silo0._total[ISilo.AssetType.Collateral].assets == 0;
    require silo0._total[ISilo.AssetType.Protected].assets == 0;
    require silo0._total[ISilo.AssetType.Debt].assets == 0;

    f(e, args);

    assert silo0._total[ISilo.AssetType.Collateral].assets == 0 <=> shareCollateralToken0.totalSupply() == 0,
        "Collateral total supply 0 <=> silo collateral assets 0";

    assert silo0._total[ISilo.AssetType.Protected].assets == 0 <=> shareProtectedCollateralToken0.totalSupply() == 0,
        "Protected total supply 0 <=> silo protected assets 0";

    assert silo0._total[ISilo.AssetType.Debt].assets == 0 <=> shareDebtToken0.totalSupply() == 0,
        "Debt total supply 0 <=> silo debt assets 0";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_interestRateTimestamp_daoAndDeployerFees" \
    --rule "VS_Silo_interestRateTimestamp_daoAndDeployerFees" \
    --verify "Silo0:certora/specs/silo/variable-changes/ValidStateSilo0.spec"
*/
rule VS_Silo_interestRateTimestamp_daoAndDeployerFees(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);

    require getSiloDataInterestRateTimestamp() == 0;
    require getSiloDataDaoAndDeployerFees() == 0;

    f(e, args);

    assert getSiloDataInterestRateTimestamp() == 0 => getSiloDataDaoAndDeployerFees() == 0,
        "Interest rate timestamp 0 <=> dao and deployer fees 0";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_totalBorrowAmount" \
    --rule "VS_Silo_totalBorrowAmount" \
    --verify "Silo0:certora/specs/silo/variable-changes/ValidStateSilo0.spec"
*/
rule VS_Silo_totalBorrowAmount(env e, method f, calldataarg args) filtered { f -> !f.isView} {
    silo0SetUp(e);

    require silo0._total[ISilo.AssetType.Collateral].assets == 0;
    require silo0._total[ISilo.AssetType.Debt].assets == 0;

    f(e, args);

    assert silo0._total[ISilo.AssetType.Debt].assets != 0 => silo0._total[ISilo.AssetType.Collateral].assets != 0,
        "Total debt assets != 0 => total collateral assets != 0";
}
