# certoraRun certora/config/vaults/consistentState.conf --rule supplyCapIsEnabled --msg supplyCapIsEnabled
# certoraRun certora/config/vaults/consistentState.conf --exclude_rule supplyCapIsEnabled

# certoraRun certora/config/vaults/distinctIdentifiers.conf 
# certoraRun certora/config/vaults/enabled.conf --exclude_rule isInDepositQThenIsInWithdrawQ
# certoraRun certora/config/vaults/enabled.conf --rule nonZeroCapHasPositiveRank --msg nonZeroCapHasPositiveRank
# certoraRun certora/config/vaults/enabled.conf --rule addedToSupplyQThenIsInWithdrawQ --msg addedToSupplyQThenIsInWithdrawQ

# certoraRun certora/config/vaults/enabled.conf --rule inWithdrawQueueIsEnabled --msg inWithdrawQueueIsEnabled
# certoraRun certora/config/vaults/enabled.conf --rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue --msg inWithdrawQueueIsEnabled2

# certoraRun certora/config/vaults/immutability.conf 
# certoraRun certora/config/vaults/lastUpdated.conf 

# certoraRun certora/config/vaults/tokenApproval.conf 

# certoraRun certora/config/vaults/liveness.conf --rule canPauseSupply
# certoraRun certora/config/vaults/marketInteractions.conf 
# certoraRun certora/config/vaults/pendingValues.conf 
# certoraRun certora/config/vaults/range.conf 
# certoraRun certora/config/vaults/reentrancy.conf 
# certoraRun certora/config/vaults/reverts.conf 
# certoraRun certora/config/vaults/roles.conf 
# certoraRun certora/config/vaults/siloVault.conf 
certoraRun certora/config/vaults/tokens.conf
# certoraRun certora/config/vaults/timelock.conf --exclude_rule removableTime