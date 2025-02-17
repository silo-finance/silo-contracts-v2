// SPDX-License-Identifier: GPL-2.0-or-later
import "DistinctIdentifiers.spec";

methods
{
    function supplyQGetAt(uint256) external returns (address) envfree;
    function supplyQLength() external returns (uint256) envfree;   
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

// Checks that markets with nonzero cap have a positive withdraw rank, according to the withdrawRank ghost variable.
invariant nonZeroCapHasPositiveRank(address id)
    config_(id).cap > 0 => withdrawRank(id) > 0
    {
    preserved {
        requireInvariant enabledHasPositiveRank(id); 
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

// in progress ------------------

persistent ghost mapping (address => bool) addedMarketIsInWithdrawQ;

hook Sstore supplyQueue[INDEX uint i] address newMarket (address oldMarket) {
    addedMarketIsInWithdrawQ[newMarket] = withdrawRank(newMarket) > 0;
}

invariant isInDepositQThenIsInWithdrawQ(address market)
    addedMarketIsInWithdrawQ[market]
    {
        preserved setSupplyQueue(address[] newSupplyQueue) with (env e) {
            requireInvariant nonZeroCapHasPositiveRank(market); 
            require setSupplyQueueInputIsValid(newSupplyQueue); //safe assumption. See setSupplyQueueRevertsOnInvalidInput
        }
        preserved {
            requireInvariant nonZeroCapHasPositiveRank(market); 
    }
}
