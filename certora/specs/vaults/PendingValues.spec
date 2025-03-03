// SPDX-License-Identifier: GPL-2.0-or-later
import "Range.spec";

function hasNoBadPendingTimelock() returns bool {
    SiloVaultHarness.PendingUint192 pendingTimelock = pendingTimelock_();

    return pendingTimelock.validAt == 0 <=> pendingTimelock.value == 0;
}

// Check that having no pending timelock value is equivalent to having its valid timestamp at 0.
invariant noBadPendingTimelock()
    hasNoBadPendingTimelock()
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to some time very far into the future.
        require e.block.timestamp < 2^63;
    }
}

// Check that the pending timelock value is always strictly smaller than the current timelock value.
invariant smallerPendingTimelock()
    assert_uint256(pendingTimelock_().value) < timelock()
{
    preserved {
        requireInvariant pendingTimelockInRange();
        requireInvariant timelockInRange();
    }
}

function hasNoBadPendingCap(address market) returns bool {
    SiloVaultHarness.PendingUint192 pendingCap = pendingCap_(market);

    return pendingCap.validAt == 0 <=> pendingCap.value == 0;
}

// Check that having no pending cap value is equivalent to having its valid timestamp at 0.
invariant noBadPendingCap(address market)
    hasNoBadPendingCap(market)
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to some time very far into the future.
        require e.block.timestamp < 2^63;
    }
}

function isGreaterPendingCap(address market) returns bool {
    uint192 pendingCapValue = pendingCap_(market).value;
    uint192 currentCapValue = config_(market).cap;

    return pendingCapValue != 0 => assert_uint256(pendingCapValue) > assert_uint256(currentCapValue);
}

// Check that the pending cap value is either 0 or strictly greater than the current cap value.
invariant greaterPendingCap(address market)
    isGreaterPendingCap(market);

function hasNoBadPendingGuardian() returns bool {
    SiloVaultHarness.PendingAddress pendingGuardian = pendingGuardian_();

    // Notice that address(0) is a valid value for a new guardian.
    return pendingGuardian.validAt == 0 => pendingGuardian.value == 0;
}

// Check that when its valid timestamp at 0 the pending guardian is the zero address.
invariant noBadPendingGuardian()
    hasNoBadPendingGuardian()
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to some time very far into the future.
        require e.block.timestamp < 2^63;
    }
}

function isDifferentPendingGuardian() returns bool {
    address pendingGuardianAddress = pendingGuardian_().value;

    return pendingGuardianAddress != 0 => pendingGuardianAddress != guardian();
}

// Check that the pending guardian is either the zero address or it is different from the current guardian.
invariant differentPendingGuardian()
    isDifferentPendingGuardian();
