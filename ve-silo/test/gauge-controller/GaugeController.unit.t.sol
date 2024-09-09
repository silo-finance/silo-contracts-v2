// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";
import {GaugeControllerDeploy} from "ve-silo/deploy/GaugeControllerDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {ERC20Mint as ERC20} from "ve-silo/test/_mocks/ERC20Mint.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc GaugeControllerTest --ffi -vvv
contract GaugeControllerTest is IntegrationTest {
    string constant internal _ETHEREUM = "Ethereum";
    int128 constant internal _GAUGE_TYPE = 0;
    uint256 constant internal _GAUGE_WEIGHT = 0;

    IGaugeController internal _controller;

    address internal _gaugeAdder = makeAddr("GaugeAdder");
    address internal _gauge = makeAddr("Gauge");
    address internal _timelock;

    event NewGaugeAdder(address addr);
    event NewGauge(address addr, int128 gaugeType, uint256 weight);

    function setUp() public {
        SiloGovernorDeploy _governanceDeploymentScript = new SiloGovernorDeploy();
        _governanceDeploymentScript.disableDeploymentsSync();

        GaugeControllerDeploy _controllerDeploymentScript = new GaugeControllerDeploy();

        _dummySiloToken();

        _governanceDeploymentScript.run();
        _controller = _controllerDeploymentScript.run();

        _timelock = getAddress(VeSiloContracts.TIMELOCK_CONTROLLER);
    }

    function testEnsureDeployedWithCorrectData() public {
        address siloToken = getAddress(SILO_TOKEN);

        assertEq(_controller.token(), siloToken, "Invalid silo token");

        assertEq(
            _controller.voting_escrow(),
            getAddress(VeSiloContracts.VOTING_ESCROW),
            "Invalid voting escrow token"
        );

        assertEq(
            _controller.admin(),
            _timelock,
            "TimelockController should be an admin"
        );
    }

    function testOnlyOnwerCanSetGaugeAdder() public {
        vm.expectRevert();
        _controller.set_gauge_adder(_gaugeAdder);

        vm.expectEmit(false, false, false, true);
        emit NewGaugeAdder(_gaugeAdder);

        vm.prank(_timelock);
        _controller.set_gauge_adder(_gaugeAdder);
    }

    function testOnlyGaugeAdderCanAddGauge() public {
        vm.prank(_timelock);
        _controller.add_type(_ETHEREUM, _GAUGE_WEIGHT);

        // should fail for an owner
        vm.prank(_timelock);
        vm.expectRevert();
        _controller.add_gauge(_gauge, _GAUGE_TYPE);

        vm.prank(_timelock);
        _controller.set_gauge_adder(_gaugeAdder);

        vm.expectEmit(false, true, true, true);
        emit NewGauge(_gauge, _GAUGE_TYPE, _GAUGE_WEIGHT);

        vm.prank(_gaugeAdder);
        _controller.add_gauge(_gauge, _GAUGE_TYPE);
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
        }
    }
}
