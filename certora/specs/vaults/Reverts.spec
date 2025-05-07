// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

methods {
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);

    function _.approve(address, uint256) external => CONSTANT;
    function SafeERC20.forceApprove(address, address, uint256) internal => CONSTANT;

    function lock() external returns (bool) envfree;
}

/*
 * @title Check that vault can't have reentrancy lock on after interaction
 * @status Verified
 */
rule reentrancyLockFalseAfterInteraction (method f, env e, calldataarg args)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    require !lock();
    f(e, args);
    assert !lock();
}

/*
 * @title Check all the revert conditions of the setCurator function.
 * @status Verified
 */
rule setCuratorRevertCondition(env e, address newCurator) {
    address owner = owner();
    address oldCurator = curator();

    setCurator@withrevert(e, newCurator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newCurator == oldCurator;
}

/*
 * @title Check all the revert conditions of the setIsAllocator function.
 * @status Verified
 */
rule setIsAllocatorRevertCondition(env e, address newAllocator, bool newIsAllocator) {
    address owner = owner();
    bool wasAllocator = isAllocator(newAllocator);

    setIsAllocator@withrevert(e, newAllocator, newIsAllocator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newIsAllocator == wasAllocator;
}

/*
 * @title Check the input validation conditions under which the setFee function reverts.
 * @notice This function can also revert if interest accrual reverts.
 * @status Verified
 */
rule setFeeInputValidation(env e, uint256 newFee) {
    address owner = owner();
    uint96 oldFee = fee();
    address feeRecipient = feeRecipient();

    setFee@withrevert(e, newFee);

    assert e.msg.value != 0 ||
           e.msg.sender != owner ||
           newFee == assert_uint256(oldFee) ||
           (newFee != 0 && feeRecipient == 0)
        => lastReverted;
}

/*
 * @title Check the input validation conditions under which the setFeeRecipient function reverts.
 * @notice This function can also revert if interest accrual reverts.
 * @status Verified
 */
rule setFeeRecipientInputValidation(env e, address newFeeRecipient) {
    address owner = owner();
    uint96 fee = fee();
    address oldFeeRecipient = feeRecipient();

    setFeeRecipient@withrevert(e, newFeeRecipient);

    assert e.msg.value != 0 ||
           e.msg.sender != owner ||
           newFeeRecipient == oldFeeRecipient ||
           (fee != 0 && newFeeRecipient == 0)
        => lastReverted;
}

/*
 * @title Check all the revert conditions of the submitGuardian function.
 * @status Verified
 */
rule submitGuardianRevertCondition(env e, address newGuardian) {
    address owner = owner();
    address oldGuardian = guardian();
    uint64 pendingGuardianValidAt = pendingGuardian_().validAt;

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    submitGuardian@withrevert(e, newGuardian);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newGuardian == oldGuardian ||
        pendingGuardianValidAt != 0;
}

/*
 * @title Check all the revert conditions of the submitCap function.
 * @status Verified
 */
rule submitCapRevertCondition(env e, address market, uint256 newSupplyCap) {
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);
    address asset = asset();
    uint256 pendingCapValidAt = pendingCap_(market).validAt;
    SiloVaultHarness.MarketConfig config = config_(market);

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;
    requireInvariant supplyCapIsEnabled(market);

    submitCap@withrevert(e, market, newSupplyCap);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        getVaultAsset(market) != asset ||
        pendingCapValidAt != 0 ||
        config.removableAt != 0 ||
        newSupplyCap == assert_uint256(config.cap) ||
        newSupplyCap >= 2^184;
}

/*
 * @title Check all the revert conditions of the submitMarketRemoval function.
 * @status Verified
 */
rule submitMarketRemovalRevertCondition(env e, address market) {
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);
    uint256 pendingCapValidAt = pendingCap_(market).validAt;
    SiloVaultHarness.MarketConfig config = config_(market);

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    submitMarketRemoval@withrevert(e, market);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        pendingCapValidAt != 0 ||
        config.cap != 0 ||
        !config.enabled ||
        config.removableAt != 0;
}

/*
 * @title Check the input validation conditions under which the setSupplyQueue function reverts.
 * @notice There are no other condition under which this function reverts, but it cannot be expressed easily because of the encoding of the universal quantifier chosen.
 * @status Verified
 */
rule setSupplyQueueInputValidation(env e, address[] newSupplyQueue) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);
    uint256 maxQueueLength = maxQueueLength();
    uint256 i;
    require i < newSupplyQueue.length;
    uint184 anyCap = config_(newSupplyQueue[i]).cap;

    setSupplyQueue@withrevert(e, newSupplyQueue);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           newSupplyQueue.length > maxQueueLength ||
           anyCap == 0
        => lastReverted;
}

/*
 * @title Check the input validation conditions under which the updateWithdrawQueue function reverts.
 * @notice This function can also revert if a market is removed when it shouldn't:
 * @notice  - a removed market should have 0 supply cap
 * @notice  - a removed market should not have a pending cap
 * @notice  - a removed market should either have no supply or (be marked for forced removal and that timestamp has elapsed)
 * @status Verified
 */
rule updateWithdrawQueueInputValidation(env e, uint256[] indexes) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);
    uint256 i;
    require i < indexes.length;
    uint256 j;
    require j < indexes.length;
    uint256 anyIndex = indexes[i];
    uint256 oldLength = withdrawQueueLength();
    uint256 anyOtherIndex = indexes[j];

    updateWithdrawQueue@withrevert(e, indexes);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           anyIndex > oldLength ||
           (i != j && anyOtherIndex == anyIndex)
        => lastReverted;
}

/*
 * @title Check the input validation conditions under which the reallocate function reverts.
 * @notice This function can also revert for non enabled markets and if the total withdrawn differs from the total supplied.
 * @status Verified
 */
rule reallocateInputValidation(env e, SiloVaultHarness.MarketAllocation[] allocations) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);

    reallocate@withrevert(e, allocations);

    assert e.msg.value != 0 ||
           !hasAllocatorRole
        => lastReverted;
}

/*
 * @title Check all the revert conditions of the revokePendingTimelock function.
 * @status Verified
 */
rule revokePendingTimelockRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}

/*
 * @title Check all the revert conditions of the revokePendingGuardian function.
 * @status Verified
 */
rule revokePendingGuardianRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}

/*
 * @title Check all the revert conditions of the revokePendingCap function.
 * @status Verified
 */
rule revokePendingCapRevertCondition(env e, address market) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);

    revokePendingCap@withrevert(e, market);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole);
}

/*
 * @title Check all the revert conditions of the revokePendingMarketRemoval function.
 * @status Verified
 */
rule revokePendingMarketRemovalRevertCondition(env e, address market) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);

    revokePendingMarketRemoval@withrevert(e, market);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole);
}

/*
 * @title Check all the revert conditions of the acceptTimelock function.
 * @status Verified
 */
rule acceptTimelockRevertCondition(env e) {
    uint256 pendingTimelockValidAt = pendingTimelock_().validAt;

    acceptTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingTimelockValidAt == 0 ||
        pendingTimelockValidAt > e.block.timestamp;
}

/*
 * @title Check all the revert conditions of the acceptGuardian function.
 * @status Verified
 */
rule acceptGuardianRevertCondition(env e) {
    uint256 pendingGuardianValidAt = pendingGuardian_().validAt;

    acceptGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingGuardianValidAt == 0 ||
        pendingGuardianValidAt > e.block.timestamp;
}

/*
 * @title Check the input validation conditions under which the acceptCap function reverts.
 * @notice This function can also revert if interest accrual reverts or if it would lead to growing the withdraw queue past the max length.
 * @status Verified
 */
rule acceptCapInputValidation(env e, address market) {
    uint256 pendingCapValidAt = pendingCap_(market).validAt;

    acceptCap@withrevert(e, market);

    assert e.msg.value != 0 ||
           pendingCapValidAt == 0 ||
           pendingCapValidAt > e.block.timestamp
        => lastReverted;
}

