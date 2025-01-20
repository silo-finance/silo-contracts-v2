// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

methods {
    function _.deposit(uint256 assets, address receiver) external => summaryDeposit(calledContract, assets, receiver) expect (uint256) ALL;
    function _.redeem(uint256 shares, address receiver, address spender) external => summaryRedeem(calledContract, shares, receiver, spender) expect (uint256) ALL;
    function _.withdraw(uint256 assets, address receiver, address spender) external => summaryWithdraw(calledContract, assets, receiver, spender) expect (uint256) ALL;
    function lastIndexWithdraw() external returns(uint256) envfree;
}

function summaryDeposit(address id, uint256 assets, address receiver) returns uint256 {
    assert assets != 0;
    assert receiver == currentContract;

    requireInvariant supplyCapIsEnabled(id);

    assert config_(id).enabled;

    // NONDET summary, which is sound because all non view functions in Morpho Blue are abstracted away.
    return (_);
}

function summaryWithdraw(address id, uint256 assets, address receiver, address spender) returns uint256 {
    assert assets != 0;
    assert receiver == currentContract;
    assert spender == currentContract;

    uint256 index = lastIndexWithdraw();
    requireInvariant inWithdrawQueueIsEnabled(index);

    assert config_(id).enabled;

    return (_);
}

function summaryRedeem(address id, uint256 shares, address receiver, address spender) returns uint256 {
    assert shares != 0;
    assert receiver == currentContract;
    assert spender == currentContract;

    uint256 index = lastIndexWithdraw();
    requireInvariant inWithdrawQueueIsEnabled(index);

    assert config_(id).enabled;
    
    // NONDET summary, which is sound because all non view functions in Morpho Blue are abstracted away.
    return (_);
}

// Check assertions in the summaries.
rule checkSummary(method f, env e, calldataarg args) {
    f(e, args);
    assert true;
}
