// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function asset() external returns(address) envfree;
    function timelock() external returns(uint256) envfree;
    function pendingTimelock_() external returns(MetaMorphoHarness.PendingUint192) envfree;
    function guardian() external returns(address) envfree;
    function pendingGuardian_() external returns(MetaMorphoHarness.PendingAddress) envfree;
    function config_(address) external returns(MetaMorphoHarness.MarketConfig) envfree;
    function pendingCap_(address) external returns(MetaMorphoHarness.PendingUint192) envfree;
    function supplyQueueLength() external returns(uint256) envfree;
    function supplyQueue(uint256) external returns(address) envfree;
    function withdrawQueueLength() external returns(uint256) envfree;
    function withdrawQueue(uint256) external returns(address) envfree;
    function fee() external returns(uint96) envfree;
    function feeRecipient() external returns(address) envfree;
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function isAllocator(address) external returns(bool) envfree;
    function skimRecipient() external returns(address) envfree;

    function minTimelock() external returns(uint256) envfree;
    function maxTimelock() external returns(uint256) envfree;
    function maxQueueLength() external returns(uint256) envfree;
    function maxFee() external returns(uint256) envfree;
}

function isPendingTimelockInRange() returns bool {
    MetaMorphoHarness.PendingUint192 pendingTimelock = pendingTimelock_();

    return pendingTimelock.validAt != 0 =>
        assert_uint256(pendingTimelock.value) <= maxTimelock() &&
        assert_uint256(pendingTimelock.value) >= minTimelock();
}

// Check that the pending timelock is bounded by the min timelock and the max timelock.
invariant pendingTimelockInRange()
    isPendingTimelockInRange();

// Check that the timelock is bounded by the min timelock and the max timelock.
invariant timelockInRange()
    timelock() <= maxTimelock() && timelock() >= minTimelock()
{
    preserved {
        requireInvariant pendingTimelockInRange();
    }
}

// Check that the fee cannot go over the max fee.
invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

// Check that the supply queue length cannot go over the max queue length.
invariant supplyQueueLengthInRange()
    supplyQueueLength() <= maxQueueLength();

// Check that the withdraw queue length cannot go over the max queue length.
invariant withdrawQueueLengthInRange()
    withdrawQueueLength() <= maxQueueLength();

function hasNoBadPendingTimelock() returns bool {
    MetaMorphoHarness.PendingUint192 pendingTimelock = pendingTimelock_();

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

function hasNoBadPendingCap(address id) returns bool {
    MetaMorphoHarness.PendingUint192 pendingCap = pendingCap_(id);

    return pendingCap.validAt == 0 <=> pendingCap.value == 0;
}

// Check that having no pending cap value is equivalent to having its valid timestamp at 0.
invariant noBadPendingCap(address id)
    hasNoBadPendingCap(id)
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to some time very far into the future.
        require e.block.timestamp < 2^63;
    }
}

function isGreaterPendingCap(address id) returns bool {
    uint192 pendingCapValue = pendingCap_(id).value;
    uint192 currentCapValue = config_(id).cap;

    return pendingCapValue != 0 => assert_uint256(pendingCapValue) > assert_uint256(currentCapValue);
}

// Check that the pending cap value is either 0 or strictly greater than the current timelock value.
invariant greaterPendingCap(address id)
    isGreaterPendingCap(id);

function hasNoBadPendingGuardian() returns bool {
    MetaMorphoHarness.PendingAddress pendingGuardian = pendingGuardian_();

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

// Check that there are no duplicate markets in the withdraw queue.
invariant distinctIdentifiers(uint256 i, uint256 j)
    i != j => withdrawQueue(i) != withdrawQueue(j)
{
    preserved updateWithdrawQueue(uint256[] indexes) with (env e) {
        requireInvariant distinctIdentifiers(indexes[i], indexes[j]);
    }
}

function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    address id = withdrawQueue(i);

    return config_(id).enabled;
}

// Check that markets in the withdraw queue are enabled.
invariant inWithdrawQueueIsEnabled(uint256 i)
    isInWithdrawQueueIsEnabled(i)
filtered {
    f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector
}



////////////////
/*
rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue(env e, uint256 i, uint256[] indexes) {
    uint256 j;
    require isInWithdrawQueueIsEnabled(indexes[i]);

    requireInvariant distinctIdentifiers(indexes[i], j);

    updateWithdrawQueue(e, indexes);

    address id = withdrawQueue(i);
    // Safe require because j is not otherwise constrained.
    // The ghost variable deletedAt is useful to make sure that markets are not permuted and deleted at the same time in updateWithdrawQueue.
    require j == deletedAt(id);

    assert isInWithdrawQueueIsEnabled(i);
}

function isWithdrawRankCorrect(address id) returns bool {
    uint256 rank = withdrawRank(id);

    if (rank == 0) return true;

    return withdrawQueue(assert_uint256(rank - 1)) == id;
}

// Checks that the withdraw rank of a market is given by the withdrawRank ghost variable.
invariant withdrawRankCorrect(address id)
    isWithdrawRankCorrect(id);

// Checks that enabled markets have a positive withdraw rank, according to the withdrawRank ghost variable.
invariant enabledHasPositiveRank(address id)
    config_(id).enabled => withdrawRank(id) > 0;

// Check that enabled markets are in the withdraw queue.
rule enabledIsInWithdrawQueue(address id) {
    require config_(id).enabled;

    requireInvariant enabledHasPositiveRank(id);
    requireInvariant withdrawRankCorrect(id);

    uint256 witness = assert_uint256(withdrawRank(id) - 1);
    assert withdrawQueue(witness) == id;
}
*/
