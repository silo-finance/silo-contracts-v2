import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_collateral_increase" \
    --rule "VC_Silo_total_collateral_increase" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_collateral_increase(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint totalDepositsBefore = getCollateralAssets();
    mathint shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint totalDepositsAfter = getCollateralAssets();
    mathint shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool isDeposit =  f.selector == depositSig() || f.selector == depositWithTypeSig();
    bool isMint = f.selector == mintSig() || f.selector == mintWithTypeSig();

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    mathint expectedBalance = siloBalanceBefore + assetsOrShares;
    mathint expectedTotalDeposits = totalDepositsBefore + assetsOrShares;

    assert totalSupplyIncreased => totalDepositsBefore < totalDepositsAfter,
        "Total deposits should increase if total supply of share tokens increased";

    assert totalSupplyIncreased => isDeposit || isMint || f.selector == transitionCollateralSig(),
        "Total supply of share tokens should increase only if deposit, mint or transitionCollateral fn was called";

    assert totalSupplyIncreased && isDeposit => expectedBalance == siloBalanceAfter &&
        (
            (!withInterest && expectedTotalDeposits == totalDepositsAfter) ||
            // with an interest it should be bigger or the same
            (withInterest && expectedTotalDeposits <= totalDepositsAfter)
        ),
        "Deposit and mint fn should increase total deposits and silo balance";

    mathint expectedSharesBalance = balanceSharesBefore + assetsOrShares;

    assert totalSupplyIncreased && isMint =>
        expectedSharesBalance - 1 == balanceSharesAfter || expectedSharesBalance == balanceSharesAfter,
        "Mint fn should increase balance of share tokens";

    assert f.selector == accrueInterestSig() && withInterest =>
         totalDepositsBefore <= totalDepositsAfter && // it may be the same if the interest is 0
         shareTokenTotalSupplyBefore == shareTokenTotalSupplyAfter,
        "AccrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_protected_increase" \
    --rule "VC_Silo_total_protected_increase" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_protected_increase(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint protectedAssetsBefore = silo0._total[ISilo.AssetType.Protected].assets;
    mathint shareTokenTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint protectedAssetsAfter = silo0._total[ISilo.AssetType.Protected].assets;
    mathint shareTokenTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool isDeposit =  f.selector == depositSig() || f.selector == depositWithTypeSig();
    bool isMint = f.selector == mintSig() || f.selector == mintWithTypeSig();

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    assert totalSupplyIncreased => protectedAssetsBefore < protectedAssetsAfter,
        "Total deposits should increase if total supply of share tokens increased";

    assert totalSupplyIncreased => isDeposit || isMint || f.selector == transitionCollateralSig(),
        "Total supply of share tokens should increase only if deposit, mint or transitionCollateral fn was called";

    assert protectedAssetsBefore < protectedAssetsAfter &&  f.selector != transitionCollateralSig() =>
            siloBalanceAfter == siloBalanceBefore + protectedAssetsAfter - protectedAssetsBefore,
        "The balance of the silo in the underlying asset should increase for the same amount";

    assert protectedAssetsBefore < protectedAssetsAfter &&  f.selector == transitionCollateralSig() =>
            siloBalanceAfter == siloBalanceBefore,
        "The balance of the silo should not change on transitionCollateral fn";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_protected_decrease" \
    --rule "VC_Silo_total_protected_decrease" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_protected_decrease(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint protectedAssetsBefore = silo0._total[ISilo.AssetType.Protected].assets;
    mathint shareTokenTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint protectedAssetsAfter = silo0._total[ISilo.AssetType.Protected].assets;
    mathint shareTokenTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyDecreased = shareTokenTotalSupplyBefore > shareTokenTotalSupplyAfter;

    assert totalSupplyDecreased => protectedAssetsBefore > protectedAssetsAfter,
        "Total deposits should decrease if total supply of share tokens decreased";

    assert totalSupplyDecreased =>
        f.selector == withdrawSig() ||
        f.selector == withdrawWithTypeSig() ||
        f.selector == withdrawWithTypeSig() ||
        f.selector == redeemSig() ||
        f.selector == liquidationCallSig() ||
        f.selector == transitionCollateralSig(),
        "Total supply of share tokens should decrease only if deposit, mint or transitionCollateral fn was called";

    assert protectedAssetsBefore > protectedAssetsAfter && f.selector != transitionCollateralSig() =>
        siloBalanceAfter == siloBalanceBefore - (protectedAssetsBefore - protectedAssetsAfter),
        "The balance of the silo in the underlying asset should decrease for the same amount";

    assert protectedAssetsBefore > protectedAssetsAfter && f.selector == transitionCollateralSig() =>
        siloBalanceAfter == siloBalanceBefore,
        "The balance of the silo should not change on transitionCollateral fn";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_debt_increase" \
    --rule "VC_Silo_total_debt_increase" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_debt_increase(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint debtAssetsBefore = silo0._total[ISilo.AssetType.Debt].assets;
    mathint shareTokenTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint debtAssetsAfter = silo0._total[ISilo.AssetType.Debt].assets;
    mathint shareTokenTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    assert totalSupplyIncreased => debtAssetsBefore < debtAssetsAfter,
        "Total debt should increase if total supply of share tokens increased";

     assert totalSupplyIncreased =>
        f.selector == borrowSig() ||
        f.selector == borrowSharesSig() ||
        f.selector == leverageSig(),
        "Total supply of share tokens should increase only if borrow, borrowShare or leverage fn was called";

    assert debtAssetsBefore < debtAssetsAfter =>
        siloBalanceAfter == siloBalanceBefore - (debtAssetsAfter - debtAssetsBefore),
        "The balance of the silo in the underlying asset should decrease for the same amount";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_debt_decrease" \
    --rule "VC_Silo_total_debt_decrease" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_debt_decrease(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint debtAssetsBefore = silo0._total[ISilo.AssetType.Debt].assets;
    mathint shareTokenTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint debtAssetsAfter = silo0._total[ISilo.AssetType.Debt].assets;
    mathint shareTokenTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyDecreased = shareTokenTotalSupplyBefore > shareTokenTotalSupplyAfter;

    assert totalSupplyDecreased && !withInterest => debtAssetsBefore > debtAssetsAfter,
        "Total debt should decrease if total supply of share tokens decreased";

     assert totalSupplyDecreased =>
        f.selector == repaySig() ||
        f.selector == repaySharesSig() ||
        f.selector == liquidationCallSig(),
        "Total supply of share tokens should decrease only if repay, repayShare or iquidationCall fn was called";

    assert debtAssetsBefore > debtAssetsAfter && !withInterest =>
        siloBalanceAfter == siloBalanceBefore + (debtAssetsBefore - debtAssetsAfter),
        "The balance of the silo in the underlying asset should increase for the same amount";
}
