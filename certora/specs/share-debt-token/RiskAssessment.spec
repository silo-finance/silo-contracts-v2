import "../silo/_common/DebtShareTokenMethods.spec";

methods {
    function balanceOf(address) external returns(uint256) envfree;
}

/*
certoraRun certora/config/shareDebt.conf \
    --parametric_contracts ShareDebtToken \
    --msg "SiloDebtToken reverse allowance" \
    --verify "ShareDebtToken:certora/specs/share-debt-token/RiskAssessment.spec"
*/
/// @title User cannot transfer debt to other user without approval
rule transferIsNotPossibleWithoutReverseApproval(method f) filtered { f -> !f.isView } {
    address recipient;

    env e;

    // we don't want recipient to do any action
    require e.msg.sender != recipient;

    // silo can mint or force transfer, so we need to exclude it
    require e.msg.sender != currentContract.silo;

    uint256 recipientBalanceBefore = balanceOf(recipient);

    if (f.selector == sig:transferFrom(address, address, uint256).selector) {
        address from;
        uint256 amount;
        // when transfering from, all we care that recipient did not allow for transfer from owner
        require receiveAllowance(from, recipient) == 0;
        transferFrom(e, from, recipient, amount);
    } else {
        // no allowance from recipient to accept debt
        require receiveAllowance(e.msg.sender, recipient) == 0;

        calldataarg args;
        f(e, args);
    }

    assert balanceOf(recipient) == recipientBalanceBefore, "recipient should not receive any debt tokens";
}
