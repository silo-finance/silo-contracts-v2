// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseStorage} from "silo-core/test/invariants/base/BaseStorage.t.sol";

import {LeverageUsingSiloFlashloanWithGeneralSwap} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {SwapRouterMock} from "silo-core/test/foundry/leverage/mocks/SwapRouterMock.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorageLeverage is BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    LeverageUsingSiloFlashloanWithGeneralSwap siloLeverage;
    SwapRouterMock swapRouterMock;
}
