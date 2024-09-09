// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {GaugeForCheckpointMock} from "../_mocks/GaugeForCheckpointMock.sol";

import {IBatchGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/IBatchGaugeCheckpointer.sol";
import {BatchGaugeCheckpointerDeploy} from "ve-silo/deploy/BatchGaugeCheckpointerDeploy.s.sol";
import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc BatchGaugeCheckpointerTest --ffi -vvv
contract BatchGaugeCheckpointerTest is IntegrationTest {
    IBatchGaugeCheckpointer internal _checkpointer;

    address internal _user = makeAddr("User");

    GaugeForCheckpointMock internal _gauge1;
    GaugeForCheckpointMock internal _gauge2;

    function setUp() public {
        BatchGaugeCheckpointerDeploy deploy = new BatchGaugeCheckpointerDeploy();
        deploy.disableDeploymentsSync();

        _checkpointer = deploy.run();

        _gauge1 = new GaugeForCheckpointMock();
        _gauge2 = new GaugeForCheckpointMock();
    }

    function testIt() public {
        ISiloChildChainGauge[] memory gauges1 = new ISiloChildChainGauge[](2);
        gauges1[0] = ISiloChildChainGauge(address(_gauge1));
        gauges1[1] = ISiloChildChainGauge(address(_gauge2));

        vm.expectRevert(abi.encodePacked(IBatchGaugeCheckpointer.EmptyUser.selector));
        _checkpointer.batchCheckpoint(address(0), gauges1);

        _checkpointer.batchCheckpoint(_user, gauges1);

        assertEq(_gauge1.userCheckpoints(_user), 1);
        assertEq(_gauge2.userCheckpoints(_user), 1);

        ISiloChildChainGauge[] memory gauges2 = new ISiloChildChainGauge[](1);
        gauges2[0] = ISiloChildChainGauge(address(_gauge1));

        _checkpointer.batchCheckpoint(_user, gauges2);

        assertEq(_gauge1.userCheckpoints(_user), 2);
    }
}
