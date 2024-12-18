// SPDX-License-Identifier: GPL-2.0-or-later
import "timelock.spec";

using Util as Util;

methods {
    function Util.libId(MetaMorphoHarness.MarketParams) external returns(address) envfree;
    function Util.libMulDivDown(uint256, uint256, uint256) external returns(uint256) envfree;
}

// Check that the fee cannot accrue to an unset fee recipient.
invariant noFeeToUnsetFeeRecipient()
    feeRecipient() == 0 => fee() == 0;

function hasSupplyCapIsEnabled(address id) returns bool {
    MetaMorphoHarness.MarketConfig config = config_(id);

    return config.cap > 0 => config.enabled;
}

// Check that having a positive supply cap implies that the market is enabled.
// This invariant is useful to conclude that markets that are not enabled cannot be interacted with (notably for reallocate).
invariant supplyCapIsEnabled(address id)
    hasSupplyCapIsEnabled(id);

function hasPendingSupplyCapHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams) returns bool {
    address id = Util.libId(marketParams);

    return pendingCap_(id).validAt > 0 => marketParams.loanToken == asset();
}

// Check that there can only be pending caps on markets where the loan asset is the asset of the vault.
invariant pendingSupplyCapHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams)
    hasPendingSupplyCapHasConsistentAsset(marketParams);

function isEnabledHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams) returns bool {
    address id = Util.libId(marketParams);

    return config_(id).enabled => marketParams.loanToken == asset();
}

// Check that having a positive cap implies that the loan asset is the asset of the vault.
invariant enabledHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams)
    isEnabledHasConsistentAsset(marketParams)
{ preserved acceptCap(MetaMorphoHarness.MarketParams _mp) with (env e) {
    requireInvariant pendingSupplyCapHasConsistentAsset(marketParams);
    require e.block.timestamp > 0;
  }
}

function hasSupplyCapIsNotMarkedForRemoval(address id) returns bool {
    MetaMorphoHarness.MarketConfig config = config_(id);

    return config.cap > 0 => config.removableAt == 0;
}

// Check that a market with a positive cap cannot be marked for removal.
invariant supplyCapIsNotMarkedForRemoval(address id)
    hasSupplyCapIsNotMarkedForRemoval(id);

function isNotEnabledIsNotMarkedForRemoval(address id) returns bool {
    MetaMorphoHarness.MarketConfig config = config_(id);

    return !config.enabled => config.removableAt == 0;
}

// Check that a non-enabled market cannot be marked for removal.
invariant notEnabledIsNotMarkedForRemoval(address id)
    isNotEnabledIsNotMarkedForRemoval(id);

// Check that a market with a pending cap cannot be marked for removal.
invariant pendingCapIsNotMarkedForRemoval(address id)
    pendingCap_(id).validAt > 0 => config_(id).removableAt == 0;

