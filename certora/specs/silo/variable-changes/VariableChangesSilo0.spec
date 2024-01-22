import "../_common/OnlySilo0SetUp.spec";
import "../_common/SiloFunctionSelector.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/IsSolventGhost.spec";
import "../_common/SimplifiedConvertions1to2Ratio.spec";

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "Viriables change Silo0" \
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

/*
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VC_Silo_dao_and_deployer_fees" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
    --rule "VC_Silo_dao_and_deployer_fees"
*/
rule VC_Silo_dao_and_deployer_fees(
    env e,
    method f,
    address receiver,
    uint256 assets
)
    filtered { f -> !f.isView }
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
