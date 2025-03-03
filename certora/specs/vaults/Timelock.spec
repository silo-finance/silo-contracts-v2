// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

methods {
    // function SiloVault._supplyBalance(address market) internal returns (uint256,uint256) => summarySupplyshares(market);
}

ghost lastSupplyShares(address) returns uint256;

function summarySupplyshares(address market) returns (uint256, uint256) {
    uint256 assets;
    uint256 shares;
    require lastSupplyShares(market) == shares;
    require assets == 0 <=> shares == 0;
    return (assets, shares);
}

persistent ghost uint256 lastTimestamp;

hook TIMESTAMP uint newTimestamp {
    // Safe require because timestamps are guaranteed to be increasing.
    require newTimestamp >= lastTimestamp;
    // Safe require as it corresponds to some time very far into the future.
    require newTimestamp < 2^63;
    lastTimestamp = newTimestamp;
}

// Show that nextGuardianUpdateTime does not revert.
rule nextGuardianUpdateTimeDoesNotRevert() {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextGuardianUpdateTime@withrevert(e);

    assert !lastReverted;
}

// Show that nextGuardianUpdateTime is increasing with time and that no change of guardian can happen before it.
rule guardianUpdateTime(env e_next, method f, calldataarg args)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // The environment e yields the current time.
    env e;

    requireInvariant timelockInRange();

    uint256 nextTime = nextGuardianUpdateTime(e);
    address prevGuardian = guardian();

    // Assume that the guardian is already set.
    require prevGuardian != 0;
    uint256 nextGuardianUpdateTimeBeforeInteraction = nextGuardianUpdateTime(e);
    // Increasing nextGuardianUpdateTime with no interaction;
    assert nextGuardianUpdateTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that guardian cannot change.
        assert guardian() == prevGuardian;
        // Increasing nextGuardianUpdateTime with an interaction;
        assert nextGuardianUpdateTime(e_next) >= nextGuardianUpdateTimeBeforeInteraction;
    }
    assert true;
}

// Show that nextCapIncreaseTime does not revert.
rule nextCapIncreaseTimeDoesNotRevert(address market) {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextCapIncreaseTime@withrevert(e, market);

    assert !lastReverted;
}

// Show that nextCapIncreaseTime is increasing with time and that no increase of cap can happen before it.
rule capIncreaseTime(env e_next, method f, calldataarg args)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // The environment e yields the current time.
    env e;

    address market;

    requireInvariant timelockInRange();

    uint256 nextTime = nextCapIncreaseTime(e, market);
    uint184 prevCap = config_(market).cap;

    uint256 nextCapIncreaseTimeBeforeInteraction = nextCapIncreaseTime(e_next, market);
    // Increasing nextCapIncreaseTime with no interaction;
    assert nextCapIncreaseTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that the cap cannot increase.
        assert config_(market).cap <= prevCap;
        // Increasing nextCapIncreaseTime with an interaction;
        assert nextCapIncreaseTime(e_next, market) >= nextCapIncreaseTimeBeforeInteraction;
    }
    assert true;
}

// Show that nextTimelockDecreaseTime does not revert.
rule nextTimelockDecreaseTimeDoesNotRevert() {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextTimelockDecreaseTime@withrevert(e);

    assert !lastReverted;
}

// Show that nextTimelockDecreaseTime is increasing with time and that no decrease of timelock can happen before it.
rule timelockDecreaseTime(env e_next, method f, calldataarg args)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // The environment e yields the current time.
    env e;

    requireInvariant timelockInRange();

    uint256 nextTime = nextTimelockDecreaseTime(e);
    uint256 prevTimelock = timelock();

    uint256 nextTimelockDecreaseTimeBeforeInteraction = nextTimelockDecreaseTime(e_next);
    // Increasing nextTimelockDecreaseTime with no interaction;
    assert nextTimelockDecreaseTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that timelock cannot decrease.
        assert timelock() >= prevTimelock;
        // Increasing nextTimelockDecreaseTime with an interaction;
        assert nextTimelockDecreaseTime(e_next) >= nextTimelockDecreaseTimeBeforeInteraction;
    }
    assert true;
}

// Show that nextRemovableTime does not revert.
rule nextRemovableTimeDoesNotRevert(address market) {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextRemovableTime@withrevert(e, market);

    assert !lastReverted;
}

// Show that nextRemovableTime is increasing with time and that no removal can happen before it.
rule removableTime(env e_next, method f, calldataarg args)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // The environment e yields the current time.
    env e;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    address market;

    requireInvariant timelockInRange();

    uint256 nextTime = nextRemovableTime(e, market);

    // Assume that the market is enabled.
    require config_(market).enabled;
    uint256 nextRemovableTimeBeforeInteraction = nextRemovableTime(e_next, market);
    // Increasing nextRemovableTime with no interaction;
    assert nextRemovableTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that no forced removal happened.
        assert lastSupplyShares(market) > 0 => config_(market).enabled;
        // Increasing nextRemovableTime with an interaction;
        assert nextRemovableTime(e_next, market) >= nextRemovableTimeBeforeInteraction;
    }
    assert true;
}
