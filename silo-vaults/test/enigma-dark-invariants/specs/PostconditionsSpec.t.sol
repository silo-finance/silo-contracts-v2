// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title PostconditionsSpec
/// @notice Postcoditions specification for the protocol
/// @dev Contains pseudo code and description for the postcondition properties in the protocol
abstract contract PostconditionsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    
    /// - POSTCONDITIONS:
    ///   - Properties that should hold true after an action is executed.
    ///   - Implemented in the /hooks and /handlers folders.
    ///   - There are two types of POSTCONDITIONS:
    ///     - GLOBAL POSTCONDITIONS (GPOST): 
    ///       - Properties that should always hold true after any action is executed.
    ///       - Checked in the `_checkPostConditions` function within the HookAggregator contract.
    ///     - HANDLER-SPECIFIC POSTCONDITIONS (HSPOST): 
    ///       - Properties that should hold true after a specific action is executed in a specific context.
    ///       - Implemented within each handler function, under the HANDLER-SPECIFIC POSTCONDITIONS section.
    
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         BASE                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora Timelock properties
    string constant GPOST_BASE_A =
        "GPOST_BASE_A: nextGuardianUpdateTime is increasing with time and that no change of guardian can happen before it";

    /// @notice related to certora Timelock properties
    string constant GPOST_BASE_B =
        "GPOST_BASE_B: nextCapIncreaseTime is increasing with time and that no increase of cap can happen before it";

    /// @notice related to certora Timelock properties
    string constant GPOST_BASE_C =
        "GPOST_BASE_C: nextTimelockDecreaseTime is increasing with time and that no decrease of timelock can happen before it";

    /// @notice related to certora Timelock properties
    string constant GPOST_BASE_D =
        "GPOST_BASE_D: nextRemovableTime is increasing with time and that no removal can happen before it";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         BALANCES                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant HSPOST_BALANCES_A = "HSPOST_BALANCES_A: balances do not change on reallocate";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          USER                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant HSPOST_USER_A =
        "HSPOST_USER_A: After a deposit or mint, deposited assets should be credited to the vaults in the supply queue that haven't reached the cap"; //TODO

    string constant HSPOST_USER_B =
        "HSPOST_USER_B: After a withdraw or redeem, assets should be withdrawn from the vaults in the withdrawal queue following the queue order"; //TODO

    string constant HSPOST_USER_C =
        "HSPOST_USER_C: After a deposit or mint, the totalAssets should increase by the amount deposited";

    string constant HSPOST_USER_D =
        "HSPOST_USER_D: After a withdraw or redeem, the totalAssets should decrease by the amount withdrawn";

    string constant HSPOST_USER_E =
        "HSPOST_USER_E: After a deposit or mint, the user balance should increase by the shares minted";

    string constant HSPOST_USER_F =
        "HSPOST_USER_F: After a withdraw or redeem, the user balance should decrease by the shares redeemed";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         QUEUES                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora LastUpdated properties
    string constant HSPOST_QUEUES_F =
        "HSPOST_QUEUES_F: any new market in the supply queue necessarily has a positive cap";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         FEES                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_FEES_A = "GPOST_FEES_A: feeRecipient must always accrue the due fee";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       ACCOUNTING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_ACCOUNTING_A =
        "GPOST_ACCOUNTING_A: totalAssets() should always increase unless a withdrawal occurs";

    string constant GPOST_ACCOUNTING_B =
        "GPOST_ACCOUNTING_B: totalAssets() should only increase due to deposits or yield";

    string constant GPOST_ACCOUNTING_C =
        "GPOST_ACCOUNTING_C: totalSupply() can only be increase with deposits or fee accrual";

    string constant GPOST_ACCOUNTING_D =
        "GPOST_ACCOUNTING_D: totalSupply() can only be decrease with withdrawals";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   DEPOSITS & WITHDRAWALS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant HSPOST_ACCOUNTING_A =
        "HSPOST_ACCOUNTING_A: deposit(amount) should always fail if totalAssets() + amount > market.cap"; 

    string constant HSPOST_ACCOUNTING_B = "HSPOST_ACCOUNTING_B: Withdrawals must never overdraw funds";

    string constant HSPOST_ACCOUNTING_C = "HSPOST_ACCOUNTING_C: A deposit or mint should increase lastTotalAssets by the amount deposited + yield";

    string constant HSPOST_ACCOUNTING_D = "HSPOST_ACCOUNTING_D: After a withdrawal or redeem lastTotalAssets' == lastTotalAssets + yield - amount withdrawn";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       REENTRANCY                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_REENTRANCY_A =
        "GPOST_REENTRANCY_A: reentrancyGuardEntered() must always be false after any transaction";
}
