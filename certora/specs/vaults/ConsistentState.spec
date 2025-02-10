// SPDX-License-Identifier: GPL-2.0-or-later
import "Timelock.spec";

methods {
    function _.asset() external => PER_CALLEE_CONSTANT;
    function _supplyBalance(address _market) internal returns (uint256, uint256);
    function SiloVaultHarness.eip712Domain() external returns (bytes1, string, string, uint256, address, bytes32, uint256[]) => NONDET DELETE;

}

// Check that the fee cannot accrue to an unset fee recipient.
invariant noFeeToUnsetFeeRecipient()
    feeRecipient() == 0 => fee() == 0;

function hasSupplyCapIsEnabled(address id) returns bool {
    SiloVaultHarness.MarketConfig config = config_(id);

    return config.cap > 0 => config.enabled;
}

// Check that having a positive supply cap implies that the market is enabled.
// This invariant is useful to conclude that markets that are not enabled cannot be interacted with (notably for reallocate).
invariant supplyCapIsEnabled(address id)
    hasSupplyCapIsEnabled(id);

function hasPendingSupplyCapHasConsistentAsset(address id) returns bool {
    return pendingCap_(id).validAt > 0 => getVaultAsset(id) == asset();
}

// Check that there can only be pending caps on markets where the loan asset is the asset of the vault.
invariant pendingSupplyCapHasConsistentAsset(address id)
    hasPendingSupplyCapHasConsistentAsset(id);

function isEnabledHasConsistentAsset(address id) returns bool {
    return config_(id).enabled => getVaultAsset(id) == asset();
}

// Check that having a positive cap implies that the loan asset is the asset of the vault.
invariant enabledHasConsistentAsset(address id)
    isEnabledHasConsistentAsset(id)
{ preserved acceptCap(address _id) with (env e) {
    requireInvariant pendingSupplyCapHasConsistentAsset(id);
    require e.block.timestamp > 0;
  }
}

function hasSupplyCapIsNotMarkedForRemoval(address id) returns bool {
    SiloVaultHarness.MarketConfig config = config_(id);

    return config.cap > 0 => config.removableAt == 0;
}

// not in withdrawal queue => market has cap == 0
function isNotInWwithdrawalQueueThenNoCap(address id) returns bool {
    
    SiloVaultHarness.MarketConfig config = config_(id);

    return config.cap > 0 => config.removableAt == 0;
}

// Check that enabled markets are in the withdraw queue.
rule notInWwithdrawalQueueThenNoCap(address id) {
    require config_(id).enabled;

    requireInvariant enabledHasPositiveRank(id);
    requireInvariant withdrawRankCorrect(id);

    uint256 witness = assert_uint256(withdrawRank(id) - 1);
    assert withdrawQueue(witness) == id;
}

// Check that a market with a positive cap cannot be marked for removal.
invariant supplyCapIsNotMarkedForRemoval(address id)
    hasSupplyCapIsNotMarkedForRemoval(id);

function isNotEnabledIsNotMarkedForRemoval(address id) returns bool {
    SiloVaultHarness.MarketConfig config = config_(id);

    return !config.enabled => config.removableAt == 0;
}

// Check that a non-enabled market cannot be marked for removal.
invariant notEnabledIsNotMarkedForRemoval(address id)
    isNotEnabledIsNotMarkedForRemoval(id);

// Check that a market with a pending cap cannot be marked for removal.
invariant pendingCapIsNotMarkedForRemoval(address id)
    pendingCap_(id).validAt > 0 => config_(id).removableAt == 0;