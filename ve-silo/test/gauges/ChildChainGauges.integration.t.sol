// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {ChildChainGaugeFactoryDeploy} from "ve-silo/deploy/ChildChainGaugeFactoryDeploy.s.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {IHookReceiverMock as IHookReceiver} from "../_mocks/IHookReceiverMock.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";

// interfaces for tests
interface IMinter {
    function minted(address _user,address _gauge) external view returns (uint256);
    function getBalancerToken() external view returns (uint256);
}

interface IVotingEscrowDelegationProxy {
    function totalSupply() external view returns (uint256);
    function adjustedBalanceOf(address _user) external view returns (uint256);
}

// FOUNDRY_PROFILE=ve-silo forge test --mc ChildChainGaugesTest --ffi -vvv
contract ChildChainGaugesTest is IntegrationTest {
    uint256 internal constant _BOB_BAL = 20e18;
    uint256 internal constant _ALICE_BAL = 20e18;
    uint256 internal constant _TOTAL_SUPPLY = 100e18;

    address internal _votingEscrowDelegationProxy = makeAddr("_votingEscrowDelegationProxy");
    address internal _l2BalancerPseudoMinter = makeAddr("_l2BalancerPseudoMinter");
    address internal _l2Multisig = makeAddr("_l2Multisig");
    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _bob = makeAddr("Bob");
    address internal _alice = makeAddr("Alice");

    IChildChainGaugeFactory internal _factory;
    ERC20 internal _siloToken;

    function setUp() public {
        setAddress(VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY, _votingEscrowDelegationProxy);
        setAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER, _l2BalancerPseudoMinter);
        setAddress(AddrKey.L2_MULTISIG, _l2Multisig);

        _mockCalls();

        ChildChainGaugeFactoryDeploy deploy = new ChildChainGaugeFactoryDeploy();
        deploy.disableDeploymentsSync();

        _factory = deploy.run();
    }

    /// @notice Ensure that a LiquidityGaugesFactory is deployed with the correct gauge implementation.
    function testEnsureFactoryDeployedWithCorrectData() public {
        assertEq(
            _factory.getGaugeImplementation(),
            getAddress(VeSiloContracts.CHILD_CHAIN_GAUGE),
            "Invalid gauge implementation"
        );
    }

    function testShouldCreateGauge() public {
        ISiloChildChainGauge gauge = _createGauge();

        assertEq(gauge.hook_receiver(), _hookReceiver, "Deployed with wrong hook receiver");
        assertEq(gauge.share_token(), _shareToken, "Deployed with wrong share token");
        assertEq(gauge.silo(), _silo, "Deployed with wrong silo");
        assertEq(gauge.silo_factory(), _siloFactory, "Deployed with wrong silo factory");
        assertEq(gauge.version(), _factory.getProductVersion(), "Deployed with wrong version");
        assertEq(address(gauge.factory()), address(_factory), "Deployed with wrong factory");

        assertEq(
            gauge.authorizer_adaptor(),
            getAddress(AddrKey.L2_MULTISIG),
            "Deployed with wrong timelockController"
        );
    }

    /// @notice Should revert if msg.sender is not ERC-20 Balances handler
    function testUpdateUsersRevert() public {
        ISiloChildChainGauge gauge = _createGauge();

        vm.expectRevert(); // dev: only balancer handler
        
        gauge.afterTokenTransfer(
            _bob,
            _BOB_BAL,
            _alice,
            _ALICE_BAL,
            _TOTAL_SUPPLY
        );
    }

    /// @notice Should update stats for two users
    function testUpdateUsers() public {
        ISiloChildChainGauge gauge = _createGauge();

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

        assertEq(gauge.working_balances(_bob), 25200000000000000000, "After 2. An invalid working balance for Bob");
        assertEq(gauge.working_balances(_alice), _ALICE_BAL, "After 2. An invalid working balance for Alice");
    }

    function _createGauge() internal returns (ISiloChildChainGauge gauge) {
        gauge = ISiloChildChainGauge(_factory.create(_hookReceiver));
        vm.label(address(gauge), "gauge");
    }

    function _mockCalls() internal {
        _siloToken = new ERC20("Silo test token", "SILO");

        vm.mockCall(
            _l2BalancerPseudoMinter,
            abi.encodeWithSelector(IMinter.getBalancerToken.selector),
            abi.encode(address(_siloToken))
        );

        vm.mockCall(
            _votingEscrowDelegationProxy,
            abi.encodeWithSelector(IVotingEscrowDelegationProxy.totalSupply.selector),
            abi.encode(_TOTAL_SUPPLY)
        );

        vm.mockCall(
            _votingEscrowDelegationProxy,
            abi.encodeWithSelector(IVotingEscrowDelegationProxy.adjustedBalanceOf.selector, _bob),
            abi.encode(_BOB_BAL)
        );

        vm.mockCall(
            _votingEscrowDelegationProxy,
            abi.encodeWithSelector(IVotingEscrowDelegationProxy.adjustedBalanceOf.selector, _alice),
            abi.encode(_ALICE_BAL)
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

        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.factory.selector),
            abi.encode(_siloFactory)
        );
    }
}
