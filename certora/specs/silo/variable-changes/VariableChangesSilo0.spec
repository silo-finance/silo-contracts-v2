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

    mathint totalDepositsBefore = silo0.total(ISilo.AssetType.Collateral);
    mathint shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint totalDepositsAfter = silo0.total(ISilo.AssetType.Collateral);
    mathint shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    mathint expectedBalance = siloBalanceBefore + assetsOrShares;
    mathint expectedTotalDeposits = totalDepositsBefore + assetsOrShares;

    assert totalSupplyIncreased => totalDepositsBefore < totalDepositsAfter,
        "Total deposits should increase if total supply of share tokens increased";

    assert totalSupplyIncreased => fnAllowedToIncreaseShareCollateralTotalSupply(f),
        "Total supply of share tokens should increase only if deposit, mint or transitionCollateral fn was called";

    assert totalSupplyIncreased && isDeposit(f) => expectedBalance == siloBalanceAfter &&
        (
            (!withInterest && expectedTotalDeposits == totalDepositsAfter) ||
            // with an interest it should be bigger or the same
            (withInterest && expectedTotalDeposits <= totalDepositsAfter)
        ),
        "Deposit fn should increase total deposits and silo balance";

    mathint expectedSharesBalance = balanceSharesBefore + assetsOrShares;

    assert totalSupplyIncreased && isMint(f) =>
        expectedSharesBalance - 1 == balanceSharesAfter || expectedSharesBalance == balanceSharesAfter,
        "Mint fn should increase balance of share tokens";

    assert f.selector == accrueInterestSig() && withInterest =>
         totalDepositsBefore <= totalDepositsAfter && // it may be the same if the interest is 0
         shareTokenTotalSupplyBefore == shareTokenTotalSupplyAfter,
        "AccrueInterest increase only Silo._total[ISilo.AssetType.Collateral).assets";
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

    mathint protectedAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    mathint shareTokenTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint shareTokenTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    assert totalSupplyIncreased => protectedAssetsBefore < protectedAssetsAfter,
        "Total deposits should increase if total supply of share tokens increased";

    assert totalSupplyIncreased => fnAllowedToIncreaseShareProtectedTotalSupply(f),
        "Total supply of share tokens should increase only if deposit, mint or transitionCollateral fn was called";

    assert protectedAssetsBefore < protectedAssetsAfter &&  f.selector != transitionCollateralSig() =>
            siloBalanceAfter == siloBalanceBefore + protectedAssetsAfter - protectedAssetsBefore,
        "The balance of the silo in the underlying asset should increase for the same amount";

    assert protectedAssetsBefore < protectedAssetsAfter &&  f.selector == transitionCollateralSig() =>
            siloBalanceAfter == siloBalanceBefore && totalSupplyIncreased,
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

    mathint protectedAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    mathint shareTokenTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint shareTokenTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyDecreased = shareTokenTotalSupplyBefore > shareTokenTotalSupplyAfter;

    assert totalSupplyDecreased => protectedAssetsBefore > protectedAssetsAfter,
        "Total deposits should decrease if total supply of share tokens decreased";

    assert totalSupplyDecreased => fnAllowedToDecreaseShareProtectedTotalSupply(f),
        "The total supply of share tokens should decrease only if allowed fn was called";

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

    mathint debtAssetsBefore = silo0.total(ISilo.AssetType.Debt);
    mathint shareTokenTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint debtAssetsAfter = silo0.total(ISilo.AssetType.Debt);
    mathint shareTokenTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyIncreased = shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter;

    assert totalSupplyIncreased => debtAssetsBefore < debtAssetsAfter,
        "Total debt should increase if total supply of share tokens increased";

    assert totalSupplyIncreased => fnAllowedToIncreaseShareDebtTotalSupply(f),
        "Total supply of share tokens should increase only if borrow, borrowShare or leverage fn was called";

    assert debtAssetsBefore < debtAssetsAfter && !withInterest =>
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

    mathint debtAssetsBefore = silo0.total(ISilo.AssetType.Debt);
    mathint shareTokenTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint debtAssetsAfter = silo0.total(ISilo.AssetType.Debt);
    mathint shareTokenTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyDecreased = shareTokenTotalSupplyBefore > shareTokenTotalSupplyAfter;

    assert totalSupplyDecreased && !withInterest => debtAssetsBefore > debtAssetsAfter,
        "Total debt should decrease if total supply of share tokens decreased";

    assert totalSupplyDecreased => fnAllowedToDecreaseShareDebtTotalSupply(f),
        "Total supply of share tokens should decrease only if repay, repayShare or iquidationCall fn was called";

    assert debtAssetsBefore > debtAssetsAfter && !withInterest =>
        siloBalanceAfter == siloBalanceBefore + (debtAssetsBefore - debtAssetsAfter),
        "The balance of the silo in the underlying asset should increase for the same amount";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_debt_share_balance" \
    --rule "VC_Silo_debt_share_balance" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_debt_share_balance(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireDebtToken0TotalAndBalancesIntegrity();

    mathint debtAssetsBefore = silo0.total(ISilo.AssetType.Debt);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);

    bool withInterest = isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint debtAssetsAfter = silo0.total(ISilo.AssetType.Debt);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(receiver);

    assert balanceSharesBefore < balanceSharesAfter => debtAssetsBefore < debtAssetsAfter,
        "The balance of share tokens should increase only if debt assets increased";

    assert balanceSharesBefore > balanceSharesAfter && !withInterest => debtAssetsBefore > debtAssetsAfter,
        "The balance of share tokens should decrease only if debt assets decreased";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_protected_share_balance" \
    --rule "VC_Silo_protected_share_balance" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_protected_share_balance(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint protectedtAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesBefore < balanceSharesAfter => protectedtAssetsBefore < protectedAssetsAfter,
        "The balance of share tokens should increase only if protected assets increased";

    assert balanceSharesBefore > balanceSharesAfter => protectedtAssetsBefore > protectedAssetsAfter,
        "The balance of share tokens should decrease only if protected assets decreased";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_collateral_share_balance" \
    --rule "VC_Silo_collateral_share_balance" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_collateral_share_balance(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireCollateralToken0TotalAndBalancesIntegrity();

    mathint collateralAssetsBefore = silo0.total(ISilo.AssetType.Collateral);
    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);

    // Turning off an interest as otherwise `decrease` can't be verified.
    require !isWithInterest(e);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint collateralAssetsAfter = silo0.total(ISilo.AssetType.Collateral);
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);

    assert balanceSharesBefore < balanceSharesAfter && !fnAllowedToChangeCollateralBalanceWithoutTotalAssets(f) =>
        collateralAssetsBefore < collateralAssetsAfter,
        "The balance of share tokens should increase only if collateral assets increased";

    assert balanceSharesBefore > balanceSharesAfter && !fnAllowedToChangeCollateralBalanceWithoutTotalAssets(f) =>
        collateralAssetsBefore > collateralAssetsAfter,
        "The balance of share tokens should decrease only if collateral assets decreased";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --verify "Silo0:certora/specs/silo/variable-changes/VC_Silo_siloData_management.spec" \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_siloData_management" \
    --method "flashLoan(address,address,uint256,bytes)" // to speed up use --method flag
*/
rule VC_Silo_siloData_management(env e, method f) filtered { f -> !f.isView } {
    silo0SetUp(e);

    uint256 accrueInterestBefore = currentContract.getSiloDataDaoAndDeployerFees();
    uint256 prevTimestamp = currentContract.getSiloDataInterestRateTimestamp();
    uint256 flashloanFee = currentContract.getFlashloanFee0();
    
    uint256 flashloanAmount;
    address receiver;

    siloFnSelector(e, f, flashloanAmount, receiver);

    uint256 accrueInterestAfter = currentContract.getSiloDataDaoAndDeployerFees();

    if (f.selector == withdrawFeesSig()) {
        assert accrueInterestBefore == 0 => accrueInterestAfter == 0;

        assert accrueInterestBefore > 0 => accrueInterestBefore > accrueInterestAfter, 
            "withdrawFees can only decrease fee";

        assert  accrueInterestBefore >= accrueInterestAfter,  "withdrawFees() is able to decrease fees";
    } else if (f.selector == flashLoanSig()) {
        if (flashloanAmount > 0 && flashloanFee > 0) {
            assert accrueInterestBefore < accrueInterestAfter, "flashLoan will increase fees";
        } else {
            assert accrueInterestBefore == accrueInterestAfter, "when no fee or no amount => no change to fees";
        }
    } else {
        assert accrueInterestBefore == accrueInterestAfter,
            "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change fees";
    }

    assert prevTimestamp == currentContract.getSiloDataInterestRateTimestamp(),
        "when _accrueInterest is OFF by AccrueInterestSimplification, no other method should change timestamp";
}
