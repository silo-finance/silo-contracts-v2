// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function asset() external returns(address) envfree;
    function timelock() external returns(uint256) envfree;
    function guardian() external returns(address) envfree;
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

    // HARNESS
    function pendingTimelock_() external returns(SiloVaultHarness.PendingUint192) envfree;
    function getVaultAsset(address) external returns(address) envfree;
    function pendingGuardian_() external returns(SiloVaultHarness.PendingAddress) envfree;
    function config_(address) external returns(SiloVaultHarness.MarketConfig) envfree;
    function pendingCap_(address) external returns(SiloVaultHarness.PendingUint192) envfree;
    function minTimelock() external returns(uint256) envfree;
    function maxTimelock() external returns(uint256) envfree;
    function maxQueueLength() external returns(uint256) envfree;
    function maxFee() external returns(uint256) envfree;

    // PATCH
    function withdrawRank(address) external returns(uint256) envfree;
    function deletedAt(address) external returns(uint256) envfree;
}

function isPendingTimelockInRange() returns bool {
    SiloVaultHarness.PendingUint192 pendingTimelock = pendingTimelock_();

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

invariant pendingCapIsUint184(address market)
    to_mathint(pendingCap_(market).value) < 2^184;

// Check that the fee cannot go over the max fee.
invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

// Check that the supply queue length cannot go over the max queue length.
invariant supplyQueueLengthInRange()
    supplyQueueLength() <= maxQueueLength();

// Check that the withdraw queue length cannot go over the max queue length.
invariant withdrawQueueLengthInRange()
    withdrawQueueLength() <= maxQueueLength();


/*
SiloVault: if a market has cap > 0, then it must be in the withdrawal queue --  via nonZeroCapHasPositiveRank   https://prover.certora.com/output/6893/2edc14f7156e4b1eb7b8cb54eb7847ff?anonymousKey=a18011de44f642de7508bc9e3bcd96ddea66adac
SiloVault: if a market is in the supplyQueue queue, then it must be in the withdrawal queue too
// SiloVault: no market should be present twice in the withdrawal queue    DONE via distinctIdentifiers
// SiloVault: if a market has removeAt != 0, then cap is zero  DONE via supplyCapIsNotMarkedForRemoval
SiloVault: SiloVault’s balance of market tokens can decrease only via withdraw or reallocate calls (violated by H-01)
    SiloVault._supplyBalance(address market) 
SiloVault: if a market is not in the withdrawal queue, then SiloVault should not have any pending approval of the asset token for it (violated by L-02)

SiloVault: external logic for rewards claiming and notification receivers should not be callable recursively (violated by L-03)
SiloVaultFactory: the SiloVault and VaultIncentivesModule created by SiloVaultFactory should both have initialOwner as their owner (violated by M-01, watch out as the team anticipated the possibility of changing the VaultIncentivesModule auth scheme)
SiloVaultFactory, SiloIncentivesControllerCLFactory: Created contract addresses should not depend on creation sequence (violated by L-01)
*/