// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

methods {
    function _.approve(address, uint256) external => CONSTANT;
    function SafeERC20.forceApprove(address, address, uint256) internal => CONSTANT;

    function lock() external returns (bool) envfree;
}

/*
 * @title Check that having the allocator role allows to pause supply on the vault.
 * @status Verified
 */
rule canPauseSupply() {
    require !lock();

    env e1; address[] newSupplyQueue;
    require e1.msg.value == 0;
    require hasAllocatorRole(e1.msg.sender);
    require newSupplyQueue.length == 0;

    setSupplyQueue@withrevert(e1, newSupplyQueue);
    assert !lastReverted;

    storage pausedSupply = lastStorage;

    env e2; uint256 assets2; address receiver2;
    require assets2 != 0;
    deposit@withrevert(e2, assets2, receiver2) at pausedSupply;
    assert lastReverted;

    env e3; uint256 shares3; address receiver3;
    uint256 assets3 = mint@withrevert(e3, shares3, receiver3) at pausedSupply;
    require assets3 != 0;
    assert lastReverted;
}

/*
 * @title Checks that currator is able to remove (disable) any market
 * @status Verified
 */
rule canForceRemoveMarket(address market) {
    require !lock();

    requireInvariant supplyCapIsEnabled(market);
    requireInvariant enabledHasConsistentAsset(market);
    // Safe require because this holds as an invariant.
    require hasPositiveSupplyCapIsUpdated(market);

    SiloVaultHarness.MarketConfig config = config_(market);
    require config.cap > 0;
    require config.removableAt == 0;
    // Assume that the withdraw queue is [X, market];
    require withdrawQueue(1) == market;
    require withdrawQueueLength() == 2;

    env e1; env e2; env e3;
    require hasCuratorRole(e1.msg.sender);
    require e2.msg.sender == e1.msg.sender;
    require e3.msg.sender == e1.msg.sender;

    require e1.msg.value == 0;
    revokePendingCap@withrevert(e1, market);
    assert !lastReverted;

    require e2.msg.value == 0;
    submitCap@withrevert(e2, market, 0);
    assert !lastReverted;

    require e3.msg.value == 0;
    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e3.block.timestamp < 2^63;
    submitMarketRemoval@withrevert(e3, market);
    assert !lastReverted;

    env e4; uint256[] newWithdrawQueue;
    require newWithdrawQueue.length == 1;
    require newWithdrawQueue[0] == 0;
    require e4.msg.value == 0;
    require hasAllocatorRole(e4.msg.sender);
    require to_mathint(e4.block.timestamp) >= e3.block.timestamp + timelock();
    updateWithdrawQueue@withrevert(e4, newWithdrawQueue);
    assert !lastReverted;

    assert !config_(market).enabled;
}
