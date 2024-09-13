// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {ERC20, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {StakelessGaugeCheckpointerAdaptorDeploy, IStakelessGaugeCheckpointerAdaptor, StakelessGaugeCheckpointerAdaptor}
    from "ve-silo/deploy/StakelessGaugeCheckpointerAdaptorDeploy.s.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/IStakelessGauge.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

contract ERC20Mint is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}

// FOUNDRY_PROFILE=ve-silo-test forge test --mc StakelessGaugeCheckpointerAdaptorTest --ffi -vvv
contract StakelessGaugeCheckpointerAdaptorTest is IntegrationTest {
    ERC20Mint internal _linkTokenMock = new ERC20Mint("Chainlink Token", "LINK");
    IStakelessGaugeCheckpointerAdaptor internal _checkpointerAdaptor;

    address internal _owner;
    address internal _newCheckpointer = makeAddr("New checkpointer");
    address internal _gauge = makeAddr("Gauge");

    event CheckpointerUpdated(address checkpointer);

    function setUp() public {
        setAddress(AddrKey.LINK, address(_linkTokenMock));

        StakelessGaugeCheckpointerAdaptorDeploy deploy = new StakelessGaugeCheckpointerAdaptorDeploy();
        deploy.disableDeploymentsSync();

        _checkpointerAdaptor = deploy.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _owner = vm.addr(deployerPrivateKey);
    }

    function testOnlyOwnerCanChangeCheckpointer() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _checkpointerAdaptor.setStakelessGaugeCheckpointer(_newCheckpointer);

        vm.expectEmit(false, false, false, true);
        emit CheckpointerUpdated(_newCheckpointer);

        _setCheckpointer();
    }

    function testCheckpointPermissions() public {
        _mockCalls();

        vm.expectRevert(StakelessGaugeCheckpointerAdaptor.OnlyCheckpointer.selector);
        _checkpointerAdaptor.checkpoint(_gauge);

        _setCheckpointer();

        vm.prank(_newCheckpointer);
        _checkpointerAdaptor.checkpoint(_gauge);
    }

    function testLeftoverETH() public {
        _mockCalls();
        _setCheckpointer();

        uint256 balance = address(_checkpointerAdaptor).balance;
        assertEq(balance, 0, "Expect have no ETH");

        payable(_newCheckpointer).transfer(1 ether);

        vm.prank(_newCheckpointer);
        _checkpointerAdaptor.checkpoint{ value: 1 ether }(_gauge);

        balance = address(_checkpointerAdaptor).balance;
        assertEq(balance, 0, "Expect have no ETH");
        assertEq(_newCheckpointer.balance, 1 ether, "Checkpointer should have ETH");
    }

    function testLeftoverLINK() public {
        _mockCalls();
        _setCheckpointer();

        uint256 balance = _linkTokenMock.balanceOf(address(_checkpointerAdaptor));
        assertEq(balance, 0, "Expect have no LINK");

        uint256 amount = 1 ether;

        _linkTokenMock.mint(address(_checkpointerAdaptor), amount);

        vm.prank(_newCheckpointer);
        _checkpointerAdaptor.checkpoint(_gauge);

        balance = _linkTokenMock.balanceOf(address(_checkpointerAdaptor));
        assertEq(balance, 0, "Expect have no LINK");
        assertEq(_linkTokenMock.balanceOf(_newCheckpointer), amount, "Checkpointer should have LINK");
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
