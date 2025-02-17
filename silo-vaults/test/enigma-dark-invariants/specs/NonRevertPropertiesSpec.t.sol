// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title NonRevertPropertiesSpec
/// @notice Properties specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract NonRevertPropertiesSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - NON REVERT (NR): 
    ///   - Properties that assert a specific function should never revert, or only revert under 
    ///   certain defined conditions.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to certora Timelock properties
    string constant NR_BASE_INVARIANT_B = "NR_BASE_INVARIANT_B: nextGuardianUpdateTime does not revert"; //TODO

    /// @notice related to certora Timelock properties
    string constant NR_BASE_INVARIANT_C = "NR_BASE_INVARIANT_C: nextCapIncreaseTime does not revert"; //TODO

    /// @notice related to certora Timelock properties
    string constant NR_BASE_INVARIANT_D = "NR_BASE_INVARIANT_D: nextTimelockDecreaseTime does not revert"; //TODO

    /// @notice related to certora Timelock properties
    string constant NR_BASE_INVARIANT_E = "NR_BASE_INVARIANT_E: nextRemovableTime does not revert"; //TODO

    string constant NR_BASE_INVARIANT_F = "NR_BASE_INVARIANT_F: claimRewards does not revert"; //TODO


    // TODO add cases for deposit / mint, etc
}
