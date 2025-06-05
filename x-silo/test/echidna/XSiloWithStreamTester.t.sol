// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {XSiloTester} from "./XSiloTester.t.sol";
import {StreamHandler} from "./handlers/permissioned/StreamHandler.t.sol";

/// @title Tester
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
/// tutorial https://secure-contracts.com/program-analysis/echidna/index.html
contract XSiloWithStreamTester is XSiloTester, StreamHandler {
    constructor() payable XSiloTester() {
    }
}
