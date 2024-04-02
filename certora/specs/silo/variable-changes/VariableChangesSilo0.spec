import "../_common/CompleteSiloSetup.spec";
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
        "AccrueInterest increase only Silo.total(ISilo.AssetType.Collateral)";
}

/**
Notice that this invariant implies the following invariant:

silo0.total[ISilo.AssetType.Protected].assets == 0 => shareProtectedCollateralToken0.totalSupply() == 0;

*/
invariant protectedAssetsBoundProtectedShareTokenTotalSupply()
    silo0.total[ISilo.AssetType.Protected].assets >= shareProtectedCollateralToken0.totalSupply() {

            preserved withdrawCollateralsToLiquidator(
                uint256 _withdrawAssetsFromCollateral,
                uint256 _withdrawAssetsFromProtected,
                address _borrower,
                address _liquidator,
                bool _receiveSToken) with (env e) {
                    requireProtectedToken0TotalAndBalancesIntegrity();
                }

            preserved redeem(uint256 _shares, address _receiver, address _owner, ISilo.AssetType _assetType) with (env e){
                requireProtectedToken0TotalAndBalancesIntegrity();
            }

            preserved transitionCollateral(uint256 _shares, address _owner, ISilo.AssetType _withdrawType) with (env e) {
                requireProtectedToken0TotalAndBalancesIntegrity();
            }

            preserved withdraw(uint256 _assets, address _receiver, address _owner, ISilo.AssetType _assetType) with (env e) {
                requireProtectedToken0TotalAndBalancesIntegrity();
            }
    }


invariant collateralAssetsBoundShareTokenTotalSupply()
    silo0.total[ISilo.AssetType.Collateral].assets >= shareCollateralToken0.totalSupply() {

            preserved withdrawCollateralsToLiquidator(
                uint256 _withdrawAssetsFromCollateral,
                uint256 _withdrawAssetsFromProtected,
                address _borrower,
                address _liquidator,
                bool _receiveSToken) with (env e) {
                    requireCollateralToken0TotalAndBalancesIntegrity();
                }

            preserved redeem(uint256 _shares, address _receiver, address _owner, ISilo.AssetType _assetType) with (env e){
                requireCollateralToken0TotalAndBalancesIntegrity();
            }

            preserved transitionCollateral(uint256 _shares, address _owner, ISilo.AssetType _withdrawType) with (env e) {
                requireCollateralToken0TotalAndBalancesIntegrity();
            }

            preserved withdraw(uint256 _assets, address _receiver, address _owner, ISilo.AssetType _assetType) with (env e) {
                requireCollateralToken0TotalAndBalancesIntegrity();
            }

             preserved withdraw(uint256 _assets, address _receiver, address _owner) with (env e) {
                requireCollateralToken0TotalAndBalancesIntegrity();
            }
    }

/**
Silo contract cannot have assets of any type when the interest rate timestamp is 0.
*/
invariant cannotHaveAssestWithZeroInterestRateTimestamp() silo0.getSiloDataInterestRateTimestamp() == 0 => 
        (silo0.total[ISilo.AssetType.Collateral].assets + 
            silo0.total[ISilo.AssetType.Protected].assets + 
             silo0.total[ISilo.AssetType.Debt].assets == 0) {

                preserved with (env e) {
                    completeSiloSetupEnv(e);
                }

                // These functions could change the assets, but they can only be called
                // with block.timestamp > 0
                preserved deposit(uint256 _assets, address _receiver) with (env e) {
                    completeSiloSetupEnv(e);
                    require e.block.timestamp > 0;
                }

                preserved deposit(uint256 _assets, address _receiver, ISilo.AssetType _assetType) with (env e) {
                    completeSiloSetupEnv(e);
                    require e.block.timestamp > 0;
                }

                preserved mint(uint256 _shares, address _receiver) with (env e) {
                    completeSiloSetupEnv(e);
                    require e.block.timestamp > 0;
                }

                preserved mint(uint256 _assets, address _receiver, ISilo.AssetType _assetType) with (env e) {
                    completeSiloSetupEnv(e);
                    require e.block.timestamp > 0;
                }

                preserved withdrawCollateralsToLiquidator(
                    uint256 _withdrawAssetsFromCollateral,
                    uint256 _withdrawAssetsFromProtected,
                    address _borrower,
                    address _liquidator,
                    bool _receiveSToken) with (env e) {
                        completeSiloSetupEnv(e);
                        requireProtectedToken0TotalAndBalancesIntegrity();
                    }

    }

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_collateral_increase" \
    --rule "VC_Silo_total_collateral_increase" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"

     collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets should decrease only on withdraw, redeem, liquidationCall.The balance of the silo in the underlying asset should decrease for the same amount as Silo._total[ISilo.AssetType.Collateral].assets decreased.
  Implementation: rule `VC_Silo_total_collateral_decrease` \
*/
rule VC_Silo_total_collateral_decrease(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
    requireInvariant cannotHaveAssestWithZeroInterestRateTimestamp();

    mathint totalDepositsBefore = silo0.getCollateralAssets(e);
    mathint protectedAssetsBefore = silo0.total[ISilo.AssetType.Protected].assets;
    mathint shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceBefore = token0.balanceOf(silo0);

    siloFnSelector(e, f, assetsOrShares, receiver);

    mathint totalDepositsAfter = silo0.getCollateralAssets(e);
    mathint protectedAssetsAfter = silo0.total[ISilo.AssetType.Protected].assets;
    mathint shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    mathint siloBalanceAfter = token0.balanceOf(silo0);

    bool totalSupplyDecreased = shareTokenTotalSupplyBefore > shareTokenTotalSupplyAfter;

    assert totalSupplyDecreased => totalDepositsBefore > totalDepositsAfter,
        "Total deposits should decrease if total supply of share tokens decreased";

    assert totalSupplyDecreased => fnAllowedToDecreaseShareCollateralTotalSupply(f),
        "The total supply of share tokens should decrease only if allowed fn was called";

    mathint siloBalanceDecrease = siloBalanceBefore - siloBalanceAfter;
    mathint totalDepositsDecrease = totalDepositsBefore - totalDepositsAfter;
    mathint protectedAssetsIncrease = protectedAssetsAfter - protectedAssetsBefore;

    assert (totalSupplyDecreased && totalDepositsDecrease == protectedAssetsIncrease) => siloBalanceDecrease == 0, 
    "The balance of the silo in the underlying asset should not change when making collateral protected";
           
    assert (totalSupplyDecreased && protectedAssetsIncrease == 0) => 
            ((receiver == silo0 && siloBalanceDecrease == 0) || 
                (receiver != silo0 && totalDepositsDecrease == siloBalanceDecrease)), 
                "The balance of the silo in the underlying asset should decrease for the 
                    same amount unless the reciever is the silo itself";
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
) filtered { f -> !f.isView } {
    completeSiloSetupEnv(e);
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
    completeSiloSetupEnv(e);

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

rule whoCanChangeAcrueInterest(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    uint256 accrueInterestBefore = currentContract.getSiloDataDaoAndDeployerFees();
    calldataarg args;
    f(e, args);
    uint256 accrueInterestAfter = currentContract.getSiloDataDaoAndDeployerFees();
    
    assert accrueInterestAfter > accrueInterestBefore => canIncreaseAccrueInterest(f);
    assert accrueInterestAfter < accrueInterestBefore => canDecreaseAccrueInterest(f);
}

rule whoCanChangeTimeStamp(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    uint256 timestampBefore = currentContract.getSiloDataInterestRateTimestamp();
    calldataarg args;
    f(e, args);
    uint256 timestampAfter = currentContract.getSiloDataInterestRateTimestamp();
    
    assert timestampAfter > timestampBefore => canIncreaseTimestamp(f);
    assert timestampAfter < timestampBefore => canDecreaseTimestamp(f);
}

rule whoCanChangeBalanceShares(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    address receiver;

    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    calldataarg args;
    f(e, args);
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    
    assert balanceSharesAfter > balanceSharesBefore => canIncreaseSharesBalance(f);
    assert balanceSharesAfter < balanceSharesBefore => canDecreaseSharesBalance(f);
}

rule whoCanChangeProtectedAssets(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    address receiver;

    mathint protectedAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    calldataarg args;
    f(e, args);
    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    
    assert protectedAssetsAfter > protectedAssetsBefore => canIncreaseProtectedAssets(f);
    assert protectedAssetsAfter < protectedAssetsBefore => canDecreaseProtectedAssets(f);
}

rule protectedSharesBalance(env e, method f, address receiver) 
    filtered { f -> !f.isView} 
{
    completeSiloSetupEnv(e);
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint protectedtAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    calldataarg args;
    f(e, args);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesBefore < balanceSharesAfter => protectedtAssetsBefore < protectedAssetsAfter,
        "The balance of share tokens should increase only if protected assets increased";

    assert balanceSharesBefore > balanceSharesAfter => protectedtAssetsBefore > protectedAssetsAfter,
        "The balance of share tokens should decrease only if protected assets decreased";
}

// save the run that violates the customers spec
// document what methods actually change it..
// the same for others
rule whoCanChangeShareTokenTotalSupply(env e, method f) filtered { f -> !f.isView } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint collateralTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint totalColateralBefore;
    totalColateralBefore, _ = getCollateralAndProtectedAssets();
    
    calldataarg args;
    f(e, args);
    mathint collateralTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint totalColateralAfter;
    totalColateralAfter, _ = getCollateralAndProtectedAssets();
    
    assert collateralTotalSupplyAfter > collateralTotalSupplyBefore <=> 
        totalColateralAfter > totalColateralBefore;

    assert totalColateralAfter > totalColateralBefore => canIncreaseTotalCollateral(f);
    assert totalColateralAfter < totalColateralBefore => canDecreaseTotalCollateral(f);
}

// debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets should decrease only on repay, repayShares, liquidationCall. accrueInterest 
// increase only Silo._total[ISilo.AssetType.Debt].assets.
rule whoCanChangeDebtShareTokenTotalSupply(env e, method f) filtered { f -> !f.isView } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint debtTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint totalDebtBefore;
    _, totalDebtBefore = getCollateralAndDebtAssets();
    
    calldataarg args;
    f(e, args);
    mathint debtTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint totalDebtAfter;
    _, totalDebtAfter = getCollateralAndDebtAssets();
    
    assert debtTotalSupplyAfter > debtTotalSupplyBefore <=> 
        totalDebtAfter > totalDebtBefore;

    assert debtTotalSupplyAfter > debtTotalSupplyBefore => canIncreaseTotalCollateral(f);
    assert debtTotalSupplyAfter < debtTotalSupplyBefore => canDecreaseTotalCollateral(f);
}

rule whoCanChangeProtectedShareTokenTotalSupply(env e, method f) filtered { f -> !f.isView } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint protectedCollateralTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint totalProtectedColateralBefore;
    _, totalProtectedColateralBefore = getCollateralAndProtectedAssets();
    
    calldataarg args;
    f(e, args);
    mathint protectedCollateralTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint totalProtectedColateralAfter;
    _, totalProtectedColateralAfter = getCollateralAndProtectedAssets();
    
    assert protectedCollateralTotalSupplyAfter > protectedCollateralTotalSupplyBefore <=> 
        totalProtectedColateralAfter > totalProtectedColateralBefore;

    assert totalProtectedColateralAfter > totalProtectedColateralBefore => canIncreaseTotalProtectedCollateral(f);
    assert totalProtectedColateralAfter < totalProtectedColateralBefore => canDecreaseTotalProtectedCollateral(f);
}

rule siloTotalsEqualBalance(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);

    mathint tokensBefore = token0.balanceOf(currentContract);
    mathint totalProtectedColateralBefore; mathint totalColateralBefore;
    totalColateralBefore, totalProtectedColateralBefore = getCollateralAndProtectedAssets();
    
    calldataarg args;
    f(e, args);
    mathint tokensAfter = token0.balanceOf(currentContract);
    mathint totalProtectedColateralAfter; mathint totalColateralAfter;
    totalColateralAfter, totalProtectedColateralAfter = getCollateralAndProtectedAssets();
    
    assert tokensBefore >= totalColateralBefore + totalProtectedColateralBefore =>
        tokensAfter >= totalColateralAfter + totalProtectedColateralAfter;
}