// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILiquidationHandler {
    function liquidationCall(
        uint256 _debtToCover,
        bool _receiveSToken,
        RandomGenerator memory random
    ) external;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Random number struct to help with stack too deep errors
    struct RandomGenerator {
        uint8 i;
        uint8 j;
        uint8 k;
    }
}
