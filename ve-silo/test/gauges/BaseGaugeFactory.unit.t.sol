// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {BaseGaugeFactoryMock} from "ve-silo/test/_mocks/BaseGaugeFactoryMock.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc BaseGaugeFactoryTest --ffi -vvv
contract BaseGaugeFactoryTest is IntegrationTest {
    bytes32 constant internal _EVENT = keccak256("GaugeCreated(address)");

    address internal _gaugeImplementation = makeAddr("Gauge implementation");

    BaseGaugeFactoryMock internal _factory;

    function setUp() public {
        _factory = new BaseGaugeFactoryMock(_gaugeImplementation);
    }

    function testCorrectImplementation() public view {
        assertEq(_factory.getGaugeImplementation(), _gaugeImplementation);
    }

    function testCreate() public {
        vm.recordLogs();

        address gauge = _factory.create();

        assertNotEq(gauge, address(0), "Gauge not created");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bool hasEvent;

        for(uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == _EVENT) {
                hasEvent = true;
                break;
            }
        }

        assertTrue(hasEvent, "Event not emitted");
    }

    function testIsGaugeFromFactory() public {
        address gauge = _factory.create();

        assertTrue(_factory.isGaugeFromFactory(gauge), "Gauge not from factory");
        assertFalse(_factory.isGaugeFromFactory(address(0)), "Gauge should not be from factory");
    }
}
