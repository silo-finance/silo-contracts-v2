// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";
import {GaugeControllerDeploy} from "ve-silo/deploy/GaugeControllerDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc GaugeControllerTest --ffi -vvv
contract GaugeControllerTest is IntegrationTest {
    IGaugeController internal _controller;

    function setUp() public {
        SiloGovernorDeploy _governanceDeploymentScript = new SiloGovernorDeploy();
        _governanceDeploymentScript.disableDeploymentsSync();

        GaugeControllerDeploy _controllerDeploymentScript = new GaugeControllerDeploy();

        _dummySiloToken();

        _governanceDeploymentScript.run();
        _controller = _controllerDeploymentScript.run();
    }

    function testEnsureDeployedWithCorrectData() public {
        address siloToken = getAddress(SILO80_WETH20_TOKEN);

        assertEq(_controller.token(), siloToken, "Invalid silo token");

        assertEq(
            _controller.voting_escrow(),
            getDeployedAddress(VeSiloContracts.VOTING_ESCROW),
            "Invalid voting escrow token"
        );

        assertEq(
            _controller.admin(),
            getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER),
            "TimelockController should be an admin"
        );
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");
            ERC20 silo8020Token = new ERC20("Silo 80/20", "SILO-80-20");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
            setAddress(getChainId(), SILO80_WETH20_TOKEN, address(silo8020Token));
        }
    }
}
