git apply ./certora/patches/SiloVault.patch
git apply ./certora/patches/SiloVaultActionsLib.patch

certoraRun certora/config/vaults/consistentState.conf --rule supplyCapIsEnabled --msg supplyCapIsEnabled
certoraRun certora/config/vaults/consistentState.conf --exclude_rule supplyCapIsEnabled

certoraRun certora/config/vaults/distinctIdentifiers.conf 
certoraRun certora/config/vaults/enabled.conf --rule nonZeroCapHasPositiveRank --msg nonZeroCapHasPositiveRank
certoraRun certora/config/vaults/enabled.conf --rule addedToSupplyQThenIsInWithdrawQ --msg addedToSupplyQThenIsInWithdrawQ
certoraRun certora/config/vaults/enabled.conf --rule inWithdrawQueueIsEnabled --msg inWithdrawQueueIsEnabled
certoraRun certora/config/vaults/enabled.conf --rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue --msg inWithdrawQueueIsEnabled2

certoraRun certora/config/vaults/immutability.conf
certoraRun certora/config/vaults/lastUpdated.conf
certoraRun certora/config/vaults/liveness.conf --rule canPauseSupply
certoraRun certora/config/vaults/marketInteractions.conf
certoraRun certora/config/vaults/pendingValues.conf
certoraRun certora/config/vaults/range.conf
certoraRun certora/config/vaults/reentrancy.conf
certoraRun certora/config/vaults/reverts.conf
certoraRun certora/config/vaults/roles.conf
certoraRun certora/config/vaults/timelock.conf --exclude_rule removableTime
certoraRun certora/config/vaults/tokens.conf --exclude_rule vaultBalanceNeutral
certoraRun certora/config/vaults/tokens.conf --rule vaultBalanceNeutral --msg vaultBalanceNeutral --parametric_contracts SiloVaultHarness
certoraRun certora/config/vaults/tokens.conf --verify SiloVaultHarness:certora/specs/vaults/MarketBalance.spec --parametric_contracts SiloVaultHarness --rule onlySpecicifiedMethodsCanDecreaseMarketBalance

certoraRun certora/config/vaults/ERC4626.conf --rule dustFavorsTheHouse --msg dustFavorsTheHouse
certoraRun certora/config/vaults/ERC4626.conf --rule onlyContributionMethodsReduceAssets --msg onlyContributionMethodsReduceAssets
certoraRun certora/config/vaults/ERC4626.conf --rule conversionWeakMonotonicity_assets --msg conversionWeakMonotonicity_assets
# certoraRun certora/config/vaults/ERC4626.conf --rule conversionWeakMonotonicity_shares --msg conversionWeakMonotonicity_shares # borderline timeout

git apply -R ./certora/patches/SiloVault.patch
git apply -R ./certora/patches/SiloVaultActionsLib.patch
