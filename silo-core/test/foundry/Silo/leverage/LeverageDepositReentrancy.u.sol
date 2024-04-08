// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ILeverageBorrower} from "silo-core/contracts/interfaces/ILeverageBorrower.sol";

import {SiloLeverageNonReentrant} from "../../_mocks/SiloLeverageNonReentrant.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LeverageDepositReentrancy
contract LeverageDepositReentrancy is Test {
    SiloLeverageNonReentrant internal _silo;

    function setUp() public {
        _silo = new SiloLeverageNonReentrant(ISiloFactory(address(0)));
    }

    function test_LeverageReentrancyCallOnDeposit() public {
        bytes memory data;

        vm.expectRevert(ISiloConfig.XReentrantCall.selector);
        // Inputs don't matter. We only need to activate/verify reentrancy protection.
        _silo.leverage(
            0, // _assets
            ILeverageBorrower(address(0)), // _receiver
            address(0), // _borrower
            false, // sameAsset
            data // _data
        );
    }
}
