// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract OpenLeveragePositionPermitReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
    }

    function verifyReentrancy() external {
    }

    function methodDescription() external pure returns (string memory description) {
        description = "openLeveragePositionPermit((address,uint256),bytes,(address,uint256,uint8),(uint256,uint256,uint8,bytes32,bytes32))";
    }
}
