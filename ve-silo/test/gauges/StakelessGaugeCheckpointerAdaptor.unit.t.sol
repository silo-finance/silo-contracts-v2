// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {StakelessGaugeCheckpointerAdaptorDeploy, IStakelessGaugeCheckpointerAdaptor, StakelessGaugeCheckpointerAdaptor}
    from "ve-silo/deploy/StakelessGaugeCheckpointerAdaptorDeploy.s.sol";

import {IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/IStakelessGauge.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc StakelessGaugeCheckpointerAdaptorTest --ffi -vvv
contract StakelessGaugeCheckpointerAdaptorTest is IntegrationTest {
    IStakelessGaugeCheckpointerAdaptor internal _checkpointerAdaptor;

    address internal _owner;
    address internal _newCheckpointer = makeAddr("New checkpointer");
    address internal _gauge = makeAddr("Gauge");

    event CheckpointerUpdated(address checkpointer);

    function setUp() public {
        StakelessGaugeCheckpointerAdaptorDeploy deploy = new StakelessGaugeCheckpointerAdaptorDeploy();
        deploy.disableDeploymentsSync();

        _checkpointerAdaptor = deploy.run();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _owner = vm.addr(deployerPrivateKey);
    }

    function testOnlyOwnerCanChangeCheckpointer() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _checkpointerAdaptor.setStakelessGaugeCheckpointer(_newCheckpointer);

        vm.expectEmit(false, false, false, true);
        emit CheckpointerUpdated(_newCheckpointer);

        _setCheckpointer();
    }

    function testCheckpointPermissions() public {
        _mockCalls();

        vm.expectRevert(StakelessGaugeCheckpointerAdaptor.OnlyCheckpointer.selector);
        _checkpointerAdaptor.checkpoint(IStakelessGauge(_gauge));

        _setCheckpointer();

        vm.prank(_newCheckpointer);
        _checkpointerAdaptor.checkpoint(IStakelessGauge(_gauge));
    }

    function testLeftoverETH() public {
        _mockCalls();
        _setCheckpointer();

        uint256 balance = address(_checkpointerAdaptor).balance;
        assertEq(balance, 0, "Expect have no ETH");

        payable(_newCheckpointer).transfer(1 ether);

        vm.prank(_newCheckpointer);
        _checkpointerAdaptor.checkpoint{ value: 1 ether }(IStakelessGauge(_gauge));

        balance = address(_checkpointerAdaptor).balance;
        assertEq(balance, 0, "Expect have no ETH");
        assertEq(_newCheckpointer.balance, 1 ether, "Checkpointer should have ETH");
    }

    function _setCheckpointer() internal {
        vm.prank(_owner);
        _checkpointerAdaptor.setStakelessGaugeCheckpointer(_newCheckpointer);
    }

    function _mockCalls() internal {
        vm.mockCall(
            _gauge,
            abi.encodeWithSelector(IStakelessGauge.checkpoint.selector),
            abi.encode(true)
        );
    }
}
