// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MaxBorrowTest} from "./MaxBorrow.i.sol";

/*
    forge test -vv --ffi --mc MaxBorrowNoLtvTest
*/
contract MaxBorrowNoLtvTest is MaxBorrowTest {
    function setUp() public override {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.SILO_LOCAL_NO_ORACLE_NO_LTV_SILO);
    }
}
