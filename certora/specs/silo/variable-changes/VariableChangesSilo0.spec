import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

methods {
    function _.mint(address _owner, address _spender, uint256 _amount) external with (env e) => mintSumm(e, calledContract, _owner, _spender, _amount) expect void UNRESOLVED;
    function _._afterTokenTransfer(address,address,uint256) internal => CONSTANT; // All calls to _afterTokenTransfer always return the same result
    function _.totalSupply() external => totalSupplySumm(calledContract) expect uint256 UNRESOLVED; // Apply the summary only if the calledContract cannot be resolved
    function _.balanceOf(address account) external => balanceOfSumm(calledContract, account) expect uint256 UNRESOLVED;
    function _.transferFrom(address from, address to, uint256 amount) external with (env e) => transferFromSumm(e, calledContract, from, to, amount) expect bool UNRESOLVED;
}

// This summary assumes that the callees are either ShareCollateralToken0 or ShareProtectedCollateralToken0.
function mintSumm(env e, address callee, address _owner, address _spender, uint256 _amount) {
    if(callee == shareCollateralToken0){
        shareCollateralToken0.mint(e, _owner, _spender, _amount);
    } else if(callee == shareProtectedCollateralToken0) {
        shareProtectedCollateralToken0.mint(e, _owner, _spender, _amount);
    }
    else {
        // You could make this statement an 'assert false' to verify that all call-sites are only for the above alternative callees
        require false;
    }
}

function totalSupplySumm(address callee) returns uint256 {
    uint256 totalSupply;
    if(callee == shareCollateralToken0){
        require totalSupply == shareCollateralToken0.totalSupply();
    } else if(callee == shareProtectedCollateralToken0) {
        require totalSupply == shareProtectedCollateralToken0.totalSupply();
    }
    else {
        // You could make this statement an 'assert false' to verify that all call-sites are only for the above alternative callees
        require false;
    }
    return totalSupply;
}

function balanceOfSumm(address callee, address account) returns uint256 {
    uint256 balanceOfAccount;
    if(callee == shareDebtToken0){
        require balanceOfAccount == shareDebtToken0.balanceOf(account);
    }
    else {
       // Assert that we could only have feasible unresolved calls to shareDebtToken0.balanceOf
        assert false, "Unresolved call to balanceOf(address) where the callee is not ShareDebtToken0";
    }
    return balanceOfAccount;
}

function transferFromSumm(env e, address callee, address from, address to, uint256 amount) returns bool {
    bool success;
    if(callee == token0) {
        require success == token0.transferFrom(e, from, to, amount);
    } else {
        assert false, "Unresolved call to transferFrom(address,address,uint256) where the callee is not Token0";
    }
    return success;
}


/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "Variables change Silo0" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"

to verify the particular function add:
--method "deposit(uint256,address)"

to run the particular rule add:
--rule "VC_Silo_totalDeposits_change_on_Deposit"
*/
rule VC_Silo_totalDeposits_change_on_Deposit(
    env e,
    method f,
    address receiver,
    uint256 assets
)
    filtered { f -> !f.isView && !f.isFallback }
{
    silo0SetUp(e);
    disableAccrueInterest(e);

    require receiver == e.msg.sender;

    uint256 totalDepositsBefore = getCollateralAssets();
    uint256 shareTokenTotalSupplyBefore = shareCollateralToken0.totalSupply();
    uint256 shareTokenBalanceBefore = shareCollateralToken0.balanceOf(e.msg.sender);

    require shareTokenBalanceBefore <= shareTokenTotalSupplyBefore;

    siloFnSelector(e, f, assets, receiver);

    uint256 totalDepositsAfter = getCollateralAssets();
    uint256 shareTokenTotalSupplyAfter = shareCollateralToken0.totalSupply();
    uint256 shareTokenBalanceAfter = shareCollateralToken0.balanceOf(e.msg.sender);

    assert f.selector == depositSig() =>
        totalDepositsBefore < totalDepositsAfter &&
        shareTokenTotalSupplyBefore < shareTokenTotalSupplyAfter &&
        shareTokenBalanceBefore < shareTokenBalanceAfter,
        "deposit fn should increase total deposits and balance";
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_total_collateral_increase" \
    --method "mint(uint256,address)" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
*/
rule VC_Silo_total_collateral_increase(env e, method f, uint256 assetsOrShares, address receiver) filtered { f -> !f.isView} {
    silo0SetUp(e);
    requireToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();

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

    assert totalSupplyIncreased => isDeposit || isMint,
        "Total supply of share tokens should increase only if deposit or mint fn was called";

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