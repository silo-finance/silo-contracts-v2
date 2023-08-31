// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/IStakelessGauge.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";

import {StakelessGaugeCheckpointerDeploy, IStakelessGaugeCheckpointer}
    from "ve-silo/deploy/StakelessGaugeCheckpointerDeploy.s.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

import {CheckpointerAdaptorMock} from "../_mocks/CheckpointerAdaptorMock.sol";

interface IArbitrumRootGauge {
    function getTotalBridgeCost() external view returns (uint256);
}

// FOUNDRY_PROFILE=ve-silo forge test --mc StakelessGaugeCheckpointerTest --ffi -vvv
contract StakelessGaugeCheckpointerTest is IntegrationTest {
    string constant internal _GAUGE_TYPE = "Arbitrum";

    IStakelessGaugeCheckpointer internal _checkpointer;
    CheckpointerAdaptorMock internal _checkpointerAdaptor;

    address internal _deployer;

    address internal _gauge = makeAddr("Gauge");
    address internal _gaugeAdder = makeAddr("Gauge adder");
    address internal _gaugeController = makeAddr("Gauge controller");
    address internal _gaugeFactory = makeAddr("Gauge factory");
    address internal _user = makeAddr("User");

    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);

        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(IGaugeAdder.getGaugeController.selector),
            abi.encode(_gaugeController)
        );

        _checkpointerAdaptor = new CheckpointerAdaptorMock();

        StakelessGaugeCheckpointerDeploy deploy = new StakelessGaugeCheckpointerDeploy();
        deploy.disableDeploymentsSync();

        setAddress(VeSiloContracts.GAUGE_ADDER, _gaugeAdder);
        setAddress(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, address(_checkpointerAdaptor));

        _checkpointer = deploy.run();
    }

    function testReceiveETHOnlyFromCheckpointAdaptor() public {
        vm.expectRevert("Only checkpoint adaptor");
        payable(address(_checkpointer)).transfer(1 ether);
    }

    function testLeftoverETH() public {
        _mockCalls();

        uint256 balance = address(_checkpointerAdaptor).balance;
        assertEq(balance, 0, "Expect have no ETH");

        balance = _user.balance;
        assertEq(balance, 0, "Expect have no ETH");

        IStakelessGauge[] memory gauges = new IStakelessGauge[](1);
        gauges[0] = IStakelessGauge(_gauge);

        vm.prank(_deployer);
        _checkpointer.addGauges(_GAUGE_TYPE, gauges);

        payable(_checkpointerAdaptor).transfer(1 ether);
        payable(_user).transfer(1 ether);

        vm.prank(_user);
        _checkpointer.checkpointSingleGauge{ value: 1 ether}(_GAUGE_TYPE, _gauge);

        balance = _user.balance;
        assertEq(balance, 2 ether, "Expect have 2 ETH");

    }

    function _mockCalls() internal {
        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(
                IGaugeAdder.isValidGaugeType.selector,
                _GAUGE_TYPE
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(
                IGaugeAdder.getFactoryForGaugeType.selector,
                _GAUGE_TYPE
            ),
            abi.encode(_gaugeFactory)
        );

        vm.mockCall(
            _gaugeController,
            abi.encodeWithSelector(
                IGaugeController.gauge_exists.selector,
                _gauge
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _gauge,
            abi.encodeWithSelector(IStakelessGauge.is_killed.selector),
            abi.encode(false)
        );

        vm.mockCall(
            _gauge,
            abi.encodeWithSelector(IArbitrumRootGauge.getTotalBridgeCost.selector),
            abi.encode(1 ether)
        );

        vm.mockCall(
            _gaugeFactory,
            abi.encodeWithSelector(
                ILiquidityGaugeFactory.isGaugeFromFactory.selector,
                _gauge
            ),
            abi.encode(true)
        );
    }
}
