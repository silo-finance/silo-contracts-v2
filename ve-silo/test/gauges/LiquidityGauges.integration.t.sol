// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {LiquidityGaugeFactoryDeploy} from "ve-silo/deploy/LiquidityGaugeFactoryDeploy.s.sol";
import {GaugeControllerDeploy} from "ve-silo/deploy/GaugeControllerDeploy.s.sol";
import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {FeesManagerTest} from "ve-silo/test/silo-tokens-minter/FeesManager.unit.t.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {ERC20Mint as ERC20} from "ve-silo/test/_mocks/ERC20Mint.sol";

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

// FOUNDRY_PROFILE=ve-silo-test forge test --mc LiquidityGaugesTest --ffi -vvv
contract LiquidityGaugesTest is IntegrationTest {
    uint256 internal constant _WEIGHT_CAP = 987;
    uint256 internal constant _BOB_BAL = 20e18;
    uint256 internal constant _ALICE_BAL = 20e18;
    uint256 internal constant _TOTAL_SUPPLY = 100e18;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    ILiquidityGaugeFactory internal _factory;
    FeesManagerTest internal _feesTest;

    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _minter = makeAddr("Mainnet silo tokens minter");
    address internal _tokenAdmin = makeAddr("Silo token admin");
    address internal _bob = makeAddr("Bob");
    address internal _alice = makeAddr("Alice");
    address internal _deployer;

    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

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

        _feesTest = new FeesManagerTest();
    }

    /// @notice Ensure that a LiquidityGaugesFactory is deployed with the correct gauge implementation.
    function testEnsureFactoryDeployedWithCorrectData() public {
        assertEq(
            _factory.getGaugeImplementation(),
            getAddress(VeSiloContracts.SILO_LIQUIDITY_GAUGE),
            "Invalid gauge implementation"
        );
    }

    /// @notice Should set fees
    function testOnlyOwnerCanSetFees() public {
        _feesTest.onlyOwnerCanSetFees(
            IFeesManager(address(_factory)),
            _DAO_FEE,
            _DEPLOYER_FEE,
            _deployer
        );
    }

    /// @notice Should revert if fees are invalid
    function testMaxFees() public {
        _feesTest.onlyOwnerCanSetFees(
            IFeesManager(address(_factory)),
            _DAO_FEE,
            _DEPLOYER_FEE + 1,
            _deployer
        );
    }

    /// @notice Should create a gauge with proper inputs.
    function testCreateGauge() public {
        ISiloLiquidityGauge gauge = _createGauge(_WEIGHT_CAP);

        assertEq(gauge.hook_receiver(), _hookReceiver, "Deployed with wrong hook receiver");
        assertEq(gauge.share_token(), _shareToken, "Deployed with wrong share token");
        assertEq(gauge.silo(), _silo, "Deployed with wrong silo");
        assertEq(gauge.silo_factory(), _siloFactory, "Deployed with wrong silo factory");
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
            _TOTAL_SUPPLY,
            0 // we don't use it in the gauge
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

        gauge.afterTokenTransfer(_bob, newBobBal, address(0), 0, newSharesTokensTotalSupply, 0);

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
            _TOTAL_SUPPLY,
            0 // we don't use it in the gauge
        );
    }

    function _createGauge(uint256 _weightCap) internal returns (ISiloLiquidityGauge gauge) {
        gauge = ISiloLiquidityGauge(_factory.create(_weightCap, _shareToken));
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
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
            abi.encode(getAddress(VeSiloContracts.GAUGE_CONTROLLER))
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
            getAddress(VeSiloContracts.VE_BOOST),
            abi.encodeWithSelector(IVeBoost.adjusted_balance_of.selector, _bob),
            abi.encode(_BOB_BAL)
        );

        vm.mockCall(
            getAddress(VeSiloContracts.VE_BOOST),
            abi.encodeWithSelector(IVeBoost.adjusted_balance_of.selector, _alice),
            abi.encode(_ALICE_BAL)
        );

        vm.mockCall(
            getAddress(VeSiloContracts.VOTING_ESCROW),
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            abi.encode(_BOB_BAL + _ALICE_BAL)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.hookReceiver.selector),
            abi.encode(_hookReceiver)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.silo.selector),
            abi.encode(_silo)
        );

        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.factory.selector),
            abi.encode(_siloFactory)
        );
    }
}
