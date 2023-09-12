// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {LiquidityGaugeFactoryDeploy} from "ve-silo/deploy/LiquidityGaugeFactoryDeploy.s.sol";
import {GaugeControllerDeploy} from "ve-silo/deploy/GaugeControllerDeploy.s.sol";
import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {IHookReceiverMock as IHookReceiver} from "../_mocks/IHookReceiverMock.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";

// interfaces for tests

interface IBalancerMinterLike {
    function getBalancerTokenAdmin() external view returns (address);
    function getGaugeController() external view returns (address);
}

interface ITokenAdminLike {
    // solhint-disable-next-line func-name-mixedcase
    function future_epoch_time_write() external returns (uint256);
    function rate() external view returns (uint256);
}

// FOUNDRY_PROFILE=ve-silo forge test --mc LiquidityGaugesTest --ffi -vvv
contract LiquidityGaugesTest is IntegrationTest {
    uint256 internal constant _WEIGHT_CAP = 987;
    uint256 internal constant _BOB_BAL = 20e18;
    uint256 internal constant _ALICE_BAL = 20e18;
    uint256 internal constant _TOTAL_SUPPLY = 100e18;

    ILiquidityGaugeFactory internal _factory;

    address internal _hookReceiver;
    address internal _shareToken;
    address internal _silo;
    address internal _minter;
    address internal _tokenAdmin;
    address internal _bob;
    address internal _alice;

    function setUp() public {
        _minter = makeAddr("Mainnet silo tokens minter");
        _tokenAdmin = makeAddr("Silo token admin");
        _hookReceiver = makeAddr("Hook receiver");
        _shareToken = makeAddr("Share token");
        _silo = makeAddr("Silo");
        _bob = makeAddr("Bob");
        _alice = makeAddr("Alice");

        SiloGovernorDeploy _governanceDeploymentScript = new SiloGovernorDeploy();
        _governanceDeploymentScript.disableDeploymentsSync();

        LiquidityGaugeFactoryDeploy _factoryDeploy = new LiquidityGaugeFactoryDeploy();
        GaugeControllerDeploy _controllerDeploymentScript = new GaugeControllerDeploy();

        _dummySiloToken();

        _governanceDeploymentScript.run();
        _controllerDeploymentScript.run();

        _mockCallsForTest();

        setAddress(VeSiloContracts.MAINNET_BALANCER_MINTER, _minter);

        _factory = _factoryDeploy.run();
    }

    /// @notice Ensure that a LiquidityGaugesFactory is deployed with the correct gauge implementation.
    function testEnsureFactoryDeployedWithCorrectData() public {
        assertEq(
            _factory.getGaugeImplementation(),
            getDeployedAddress(VeSiloContracts.SILO_LIQUIDITY_GAUGE),
            "Invalid gauge implementation"
        );
    }

    /// @notice Should create a gauge with proper inputs.
    function testCreateGauge() public {
        ISiloLiquidityGauge gauge = _createGauge(_WEIGHT_CAP);

        assertEq(gauge.hook_receiver(), _hookReceiver, "Deployed with wrong hook receiver");
        assertEq(gauge.share_token(), _shareToken, "Deployed with wrong share token");
        assertEq(gauge.silo(), _silo, "Deployed with wrong silo");
        assertEq(gauge.getRelativeWeightCap(), _WEIGHT_CAP, "Deployed with wrong relative weight cap");
    }

    /// @notice Should update stats for two users
    function testUpdateUsers() public {
        ISiloLiquidityGauge gauge = _createGauge(_WEIGHT_CAP);
        vm.label(address(gauge), "gauge");

        assertEq(gauge.working_balances(_bob), 0, "Before. An invalid working balance for Bob");
        assertEq(gauge.working_balances(_alice), 0, "Before. An invalid working balance for Alice");

        uint256 integrateCheckpoint = gauge.integrate_checkpoint();
        uint256 timestamp = integrateCheckpoint + 3_600;

        vm.warp(timestamp);
        vm.prank(_hookReceiver);

        gauge.afterTokenTransfer(
            _bob,
            _BOB_BAL,
            _alice,
            _ALICE_BAL,
            _TOTAL_SUPPLY
        );

        integrateCheckpoint = gauge.integrate_checkpoint();

        assertEq(integrateCheckpoint, timestamp, "Wrong timestamp of the last checkpoint");

        assertEq(gauge.working_balances(_bob), _BOB_BAL, "After. An invalid working balance for Bob");
        assertEq(gauge.working_balances(_alice), _ALICE_BAL, "After. An invalid working balance for Alice");

        timestamp += 3_600;
        vm.warp(timestamp);
        vm.prank(_hookReceiver);

        uint256 newBobBal = _BOB_BAL + 10e18;
        uint256 newSharesTokensTotalSupply = _TOTAL_SUPPLY + 10e18;

        gauge.afterTokenTransfer(_bob, newBobBal, address(0), 0, newSharesTokensTotalSupply);

        assertEq(gauge.working_balances(_bob), newBobBal, "After 2. An invalid working balance");
        assertEq(gauge.working_balances(_alice), _ALICE_BAL, "After 2. An invalid working balance for Alice");
    }

    /// @notice Should revert if msg.sender is not ERC-20 Balances handler
    function testUpdateUsersRevert() public {
        ISiloLiquidityGauge gauge = _createGauge(_WEIGHT_CAP);
        vm.label(address(gauge), "gauge");

        vm.expectRevert(); // dev: only silo hook receiver
        
        gauge.afterTokenTransfer(
            _bob,
            _BOB_BAL,
            _alice,
            _ALICE_BAL,
            _TOTAL_SUPPLY
        );
    }

    function _createGauge(uint256 _weightCap) internal returns (ISiloLiquidityGauge gauge) {
        gauge = ISiloLiquidityGauge(_factory.create(_weightCap, _hookReceiver));
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");
            ERC20 silo8020Token = new ERC20("Silo 80/20", "SILO-80-20");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
            setAddress(getChainId(), SILO80_WETH20_TOKEN, address(silo8020Token));
        }
    }

    // solhint-disable-next-line function-max-lines
    function _mockCallsForTest() internal {
        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinterLike.getBalancerTokenAdmin.selector),
            abi.encode(_tokenAdmin)
        );

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinterLike.getGaugeController.selector),
            abi.encode(getDeployedAddress(VeSiloContracts.GAUGE_CONTROLLER))
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(ITokenAdminLike.future_epoch_time_write.selector),
            abi.encode(100)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(ITokenAdminLike.rate.selector),
            abi.encode(100)
        );

        vm.mockCall(
            getDeployedAddress(VeSiloContracts.VE_BOOST),
            abi.encodeWithSelector(IVeBoost.adjusted_balance_of.selector, _bob),
            abi.encode(_BOB_BAL)
        );

        vm.mockCall(
            getDeployedAddress(VeSiloContracts.VE_BOOST),
            abi.encodeWithSelector(IVeBoost.adjusted_balance_of.selector, _alice),
            abi.encode(_ALICE_BAL)
        );

        vm.mockCall(
            getDeployedAddress(VeSiloContracts.VOTING_ESCROW),
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            abi.encode(_BOB_BAL + _ALICE_BAL)
        );

        vm.mockCall(
            _hookReceiver,
            abi.encodeWithSelector(IHookReceiver.shareToken.selector),
            abi.encode(_shareToken)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.silo.selector),
            abi.encode(_silo)
        );
    }
}
