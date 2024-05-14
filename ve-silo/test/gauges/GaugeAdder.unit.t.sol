// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IGaugeAdder, ILiquidityGaugeFactory}
    from "ve-silo/contracts/gauges/gauge-adder/GaugeAdder.sol";

import {GaugeAdderDeploy} from "ve-silo/deploy/GaugeAdderDeploy.s.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

interface IGaugeController {
    // solhint-disable-next-line func-name-mixedcase
    function add_gauge(address _gauge, int128 _gaugeType) external;
}

// FOUNDRY_PROFILE=ve-silo-test forge test --mc GaugeAdderTest --ffi -vvv
contract GaugeAdderTest is IntegrationTest {
    int128 internal constant _ETHEREUM_GAUGE_CONTROLLER_TYPE = 0;
    string internal constant _ETHEREUM = "Ethereum";

    address internal _controller = makeAddr("GaugeController");
    address internal _factory = makeAddr("LiquidityGaugeFactory");
    address internal _gauge = makeAddr("Gauge");
    address internal _deployer;

    IGaugeAdder internal _gaugeAdder;

    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        GaugeAdderDeploy deploy = new GaugeAdderDeploy();
        deploy.disableDeploymentsSync();

        setAddress(VeSiloContracts.GAUGE_CONTROLLER, _controller);
        setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _deployer);

        _gaugeAdder = deploy.run();
    }

    function testShouldAddGauge() public {
        _mockCalls();

        vm.prank(_deployer);
        _gaugeAdder.addGaugeType(_ETHEREUM);

        vm.prank(_deployer);
        _gaugeAdder.setGaugeFactory(ILiquidityGaugeFactory(_factory), _ETHEREUM);

        vm.prank(_deployer);
        _gaugeAdder.addGauge(_gauge, _ETHEREUM);
    }

    function _mockCalls() internal {
        vm.mockCall(
            _controller,
            abi.encodeWithSelector(
                IGaugeController.add_gauge.selector,
                _gauge,
                _ETHEREUM_GAUGE_CONTROLLER_TYPE
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _factory,
            abi.encodeWithSelector(
                ILiquidityGaugeFactory.isGaugeFromFactory.selector,
                _gauge
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _factory,
            abi.encodeWithSelector(
                ILiquidityGaugeFactory.isGaugeFromFactory.selector,
                address(0)
            ),
            abi.encode(false)
        );
    }
}
