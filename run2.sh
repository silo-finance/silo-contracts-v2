# certoraRun.py certora/config/vaults/consistentState.conf --prover_version master --rule supplyCapIsEnabled --msg supplyCapIsEnabled
# certoraRun.py certora/config/vaults/consistentState.conf --prover_version master --exclude_rule supplyCapIsEnabled

# certoraRun.py certora/config/vaults/distinctIdentifiers.conf --prover_version master
# certoraRun.py certora/config/vaults/enabled.conf --prover_version master --exclude_rule isInDepositQThenIsInWithdrawQ
# certoraRun.py certora/config/vaults/enabled.conf --prover_version master --rule nonZeroCapHasPositiveRank --msg nonZeroCapHasPositiveRank
# certoraRun.py certora/config/vaults/enabled.conf --prover_version master --rule addedToSupplyQThenIsInWithdrawQ --msg addedToSupplyQThenIsInWithdrawQ

# certoraRun.py certora/config/vaults/enabled.conf --prover_version master --rule inWithdrawQueueIsEnabled --msg inWithdrawQueueIsEnabled
# certoraRun.py certora/config/vaults/enabled.conf --prover_version master --rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue --msg inWithdrawQueueIsEnabled2

# certoraRun.py certora/config/vaults/immutability.conf --prover_version master
# certoraRun.py certora/config/vaults/lastUpdated.conf --prover_version master

# certoraRun.py certora/config/vaults/tokenApproval.conf --prover_version master

# certoraRun.py certora/config/vaults/liveness.conf --prover_version master --rule canPauseSupply
# certoraRun.py certora/config/vaults/marketInteractions.conf --prover_version master
# certoraRun.py certora/config/vaults/pendingValues.conf --prover_version master
# certoraRun.py certora/config/vaults/range.conf --prover_version master
# certoraRun.py certora/config/vaults/reentrancy.conf --prover_version master
# certoraRun.py certora/config/vaults/reverts.conf --prover_version master
# certoraRun.py certora/config/vaults/roles.conf --prover_version master
# certoraRun.py certora/config/vaults/siloVault.conf --prover_version master
# certoraRun.py certora/config/vaults/tokens.conf --prover_version master
# certoraRun.py certora/config/vaults/timelock.conf --prover_version master --exclude_rule removableTime

certoraRun.py certora/config/vaults/tokens.conf --prover_version master --verify SiloVaultHarness:certora/specs/vaults/MarketBalance.spec --msg onlySpecicifeidMethodsCanDecreaseMarketBalance --parametric_contracts SiloVaultHarness
