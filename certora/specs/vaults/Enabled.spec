// SPDX-License-Identifier: GPL-2.0-or-later
import "DistinctIdentifiers.spec";

methods
{
    function supplyQGetAt(uint256) external returns (address) envfree;
    function supplyQLength() external returns (uint256) envfree;   
    function withdrawQGetAt(uint256) external returns (address) envfree;
    function withdrawQLength() external returns (uint256) envfree;   
}

function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    address market = withdrawQueue(i);

    return config_(market).enabled;
}

// Check that markets in the withdraw queue are enabled.
invariant inWithdrawQueueIsEnabled(uint256 i)
    isInWithdrawQueueIsEnabled(i)
filtered {
    f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector
}

rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue(env e, uint256 i, uint256[] indexes) {
    uint256 j;
    require isInWithdrawQueueIsEnabled(indexes[i]);

    requireInvariant distinctIdentifiers(indexes[i], j);

    updateWithdrawQueue(e, indexes);

    address market = withdrawQueue(i);
    // Safe require because j is not otherwise constrained.
    // The ghost variable deletedAt is useful to make sure that markets are not permuted and deleted at the same time in updateWithdrawQueue.
    require j == deletedAt(market);

    assert isInWithdrawQueueIsEnabled(i);
}

function isWithdrawRankCorrect(address market) returns bool {
    uint256 rank = withdrawRank(market);

    if (rank == 0) return true;

    return withdrawQueue(assert_uint256(rank - 1)) == market;
}

// Checks that the withdraw rank of a market is given by the withdrawRank ghost variable.
invariant withdrawRankCorrect(address market)
    isWithdrawRankCorrect(market);

// Checks that enabled markets have a positive withdraw rank, according to the withdrawRank ghost variable.
invariant enabledHasPositiveRank(address market)
    config_(market).enabled => withdrawRank(market) > 0;


// Check that enabled markets are in the withdraw queue.
rule enabledIsInWithdrawQueue(address market) {
    require config_(market).enabled;

    requireInvariant enabledHasPositiveRank(market);
    requireInvariant withdrawRankCorrect(market);

    uint256 witness = assert_uint256(withdrawRank(market) - 1);
    assert withdrawQueue(witness) == market;
}

// Checks that markets with nonzero cap have a positive withdraw rank, according to the withdrawRank ghost variable.
invariant nonZeroCapHasPositiveRank(address market)
    config_(market).cap > 0 => withdrawRank(market) > 0
    {
    preserved {
        requireInvariant enabledHasPositiveRank(market); 
    }
}

function setSupplyQueueInputIsValid(address[] newSupplyQueue) returns bool
{
    uint256 i;
    require i < newSupplyQueue.length;
    uint184 someCap = config_(newSupplyQueue[i]).cap;
    bool result;
    require result == false => someCap == 0;
    return result;
}

// https://prover.certora.com/output/6893/51445a2d85b8428a9dcda8062811847e?anonymousKey=aee1daaea5bf150b10060398b47d34d107150cf9
rule setSupplyQueueRevertsOnInvalidInput(env e, address[] newSupplyQueue)
{
    setSupplyQueue@withrevert(e, newSupplyQueue);
    bool reverted = lastReverted;
    assert !setSupplyQueueInputIsValid(newSupplyQueue) => reverted;
}

invariant addedToSupplyQThenIsInWithdrawQ(uint256 supplyQIndex)
    supplyQIndex < supplyQLength() => withdrawRank(supplyQGetAt(supplyQIndex)) > 0
    filtered { f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector /* the method allowed to break this */ }
    {
        preserved setSupplyQueue(address[] newSupplyQueue) with (env e) {
            requireInvariant nonZeroCapHasPositiveRank(newSupplyQueue[supplyQIndex]); 
            require setSupplyQueueInputIsValid(newSupplyQueue); //safe assumption. See setSupplyQueueRevertsOnInvalidInput
        }
        preserved {
            requireInvariant nonZeroCapHasPositiveRank(supplyQGetAt(supplyQIndex)); 
    }
}
