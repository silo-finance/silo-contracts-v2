// SPDX-License-Identifier: GPL-2.0-or-later
import "PendingValues.spec";

/*
 * @title Check that there are no duplicate markets in the withdraw queue.
 * @status Verified
 */
invariant distinctIdentifiers(uint256 i, uint256 j)
    i != j => withdrawQueue(i) != withdrawQueue(j)
{
    preserved updateWithdrawQueue(uint256[] indexes) with (env e) {
        requireInvariant distinctIdentifiers(indexes[i], indexes[j]);
    }
}
