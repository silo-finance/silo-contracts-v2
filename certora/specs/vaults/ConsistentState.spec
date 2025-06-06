// SPDX-License-Identifier: GPL-2.0-or-later
import "Timelock.spec";

methods {
    function _.asset() external => PER_CALLEE_CONSTANT;
    function _supplyBalance(address _market) internal returns (uint256, uint256);
    function SiloVaultHarness.eip712Domain() external returns (bytes1, string, string, uint256, address, bytes32, uint256[]) => NONDET DELETE;

}

/*
 * @title Check that the fee cannot accrue to an unset fee recipient.
 * @status Verified
 */
invariant noFeeToUnsetFeeRecipient()
    feeRecipient() == 0 => fee() == 0;

function hasSupplyCapIsEnabled(address market) returns bool {
    SiloVaultHarness.MarketConfig config = config_(market);

    return config.cap > 0 => config.enabled;
}

/*
 * @title Check that having a positive supply cap implies that the market is enabled.
 * @status Verified
 * @notice This invariant is useful to conclude that markets that are not enabled cannot be interacted with (notably for reallocate).
 */
invariant supplyCapIsEnabled(address market)
    hasSupplyCapIsEnabled(market);

function hasPendingSupplyCapHasConsistentAsset(address market) returns bool {
    return pendingCap_(market).validAt > 0 => getVaultAsset(market) == asset();
}

/*
 * @title Check that there can only be pending caps on markets where the loan asset is the asset of the vault.
 * @status Verified
 */
invariant pendingSupplyCapHasConsistentAsset(address market)
    hasPendingSupplyCapHasConsistentAsset(market);

function isEnabledHasConsistentAsset(address market) returns bool {
    return config_(market).enabled => getVaultAsset(market) == asset();
}

/*
 * @title Check that having a positive cap implies that the loan asset is the asset of the vault.
 * @status Verified
 */
invariant enabledHasConsistentAsset(address market)
    isEnabledHasConsistentAsset(market)
{ preserved acceptCap(address _market) with (env e) {
    requireInvariant pendingSupplyCapHasConsistentAsset(market);
    require e.block.timestamp > 0;
  }
}

function hasSupplyCapIsNotMarkedForRemoval(address market) returns bool {
    SiloVaultHarness.MarketConfig config = config_(market);

    return config.cap > 0 => config.removableAt == 0;
}

// not in withdrawal queue => market has cap == 0
function isNotInWwithdrawalQueueThenNoCap(address market) returns bool {
    
    SiloVaultHarness.MarketConfig config = config_(market);

    return config.cap > 0 => config.removableAt == 0;
}

/*
 * @title Check that enabled markets are in the withdraw queue.
 * @status Verified
 */
rule enabledIsInWithdrawalQueue(address market) {
    require config_(market).enabled;

    requireInvariant enabledHasPositiveRank(market);
    requireInvariant withdrawRankCorrect(market);

    uint256 witness = assert_uint256(withdrawRank(market) - 1);
    assert withdrawQueue(witness) == market;
}

/*
 * @title Check that a market with a positive cap cannot be marked for removal.
 * @status Verified
 */
invariant supplyCapIsNotMarkedForRemoval(address market)
    hasSupplyCapIsNotMarkedForRemoval(market);

function isNotEnabledIsNotMarkedForRemoval(address market) returns bool {
    SiloVaultHarness.MarketConfig config = config_(market);

    return !config.enabled => config.removableAt == 0;
}

/*
 * @title Check that a non-enabled market cannot be marked for removal.
 * @status Verified
 */
invariant notEnabledIsNotMarkedForRemoval(address market)
    isNotEnabledIsNotMarkedForRemoval(market);

/*
 * @title Check that a market with a pending cap cannot be marked for removal.
 * @status Verified
 */
invariant pendingCapIsNotMarkedForRemoval(address market)
    pendingCap_(market).validAt > 0 => config_(market).removableAt == 0;

