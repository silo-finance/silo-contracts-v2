// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV): 
    ///   - Properties that should always hold true in the system. 
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         BASE                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora ConsistentState properties
    string constant INV_BASE_A = "INV_BASE_A: positive supply cap implies that the market is enabled";

    /// @notice related to certora ConsistentState properties
    string constant INV_BASE_C = "INV_BASE_C: a market with a positive cap cannot be marked for removal";

    /// @notice related to certora ConsistentState properties
    string constant INV_BASE_D = "INV_BASE_D: a non-enabled market cannot be marked for removal";

    /// @notice related to certora ConsistentState properties
    string constant INV_BASE_E = "INV_BASE_E: a market with a pending cap cannot be marked for removal";

    /// @notice related to certora Range properties
    string constant INV_BASE_F = "INV_BASE_F: the fee cannot go over the max fee";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         QUEUES                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora DistinctIdentifiers properties
    string constant INV_QUEUES_A = "INV_QUEUES_A: there are no duplicate markets in the withdraw queue";

    /// @notice related to certora Enabled properties
    string constant INV_QUEUES_B = "INV_QUEUES_B: markets in the withdraw queue are enabled";

    /// @notice related to certora Enabled properties
    string constant INV_QUEUES_E = "INV_QUEUES_E: enabled markets are in the withdraw queue";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       TIMELOCK                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora PendingValues properties
    string constant INV_TIMELOCK_A =
        "INV_TIMELOCK_A: pending timelock value is always strictly smaller than the current timelock value";

    /// @notice related to certora PendingValues properties
    string constant INV_TIMELOCK_D =
        "INV_TIMELOCK_D: pending guardian is either the zero address or it is different from the current guardian";

    /// @notice related to certora Range properties
    string constant INV_TIMELOCK_E =
        "INV_TIMELOCK_E: the pending timelock is bounded by the min timelock and the max timelock";

    /// @notice related to certora Range properties
    string constant INV_TIMELOCK_F = "INV_TIMELOCK_F: the timelock is bounded by the min timelock and the max timelock";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        MARKETS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora PendingValues properties
    string constant INV_MARKETS_A =
        "INV_MARKETS_A: having no pending cap value is equivalent to having its valid timestamp at 0";

    /// @notice related to certora PendingValues properties
    string constant INV_MARKETS_B =
        "INV_MARKETS_B: the pending cap value is either 0 or strictly greater than the current cap value";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         FEES                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_FEES_A = "INV_FEES_A: feeRecipient == address(0) <=> fee == 0";

    string constant INV_FEES_B = "INV_FEES_B: accruedFee == totalYield * feeRate/WAD";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       ACCOUNTING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_ACCOUNTING_A = "INV_ACCOUNTING_A: totalAssets() must always be at least lastTotalAssets";

    string constant INV_ACCOUNTING_B = "INV_ACCOUNTING_B: convertToShares(convertToAssets(x)) must always return x";

    string constant INV_ACCOUNTING_C = "INV_ACCOUNTING_C: vault should not hold any asset balance";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   DEPOSITS & WITHDRAWALS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_DEPOSIT_WITHDRAW_A =
        "INV_DEPOSIT_WITHDRAW_A: Max withdrawal must always be limited by available assets"; // TODO

    /*     
    - ASSETS
        - ROUNDING -> BOUND ERRORS*
        - vault should not have any asset tokens*
    - EXCHANGE RATE
        - ROUNDTRIP -> CONVERT -> SHARES/ASSETS, BIJECTION*
    - MARKET BALANCES
    - IDLE VAULT
        - no conversion rate 1:1 ratio
    - DOS*
    - derive rules from findings
     */
}
