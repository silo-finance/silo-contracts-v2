// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {ChildChainGaugeFactoryDeploy} from "ve-silo/deploy/ChildChainGaugeFactoryDeploy.s.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {FeesManagerTest} from "ve-silo/test/silo-tokens-minter/FeesManager.unit.t.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {ERC20Mint as ERC20} from "ve-silo/test/_mocks/ERC20Mint.sol";
import {IMinterLike as IMinter} from "ve-silo/test/gauges/interfaces/IMinterLike.sol";
import {IVotingEscrowDelegationProxyLike} from "ve-silo/test/gauges/interfaces/IVotingEscrowDelegationProxyLike.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc ChildChainGaugesTest --ffi -vvv
contract ChildChainGaugesTest is IntegrationTest {
    uint256 internal constant _BOB_BAL = 20e18;
    uint256 internal constant _ALICE_BAL = 20e18;
    uint256 internal constant _TOTAL_SUPPLY = 100e18;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    address internal _votingEscrowDelegationProxy = makeAddr("_votingEscrowDelegationProxy");
    address internal _l2BalancerPseudoMinter = makeAddr("_l2BalancerPseudoMinter");
    address internal _l2Multisig = makeAddr("_l2Multisig");
    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _bob = makeAddr("Bob");
    address internal _alice = makeAddr("Alice");
    address internal _deployer;

    IChildChainGaugeFactory internal _factory;
    ERC20 internal _siloToken;
    FeesManagerTest internal _feesTest;

    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        setAddress(VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY, _votingEscrowDelegationProxy);
        setAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER, _l2BalancerPseudoMinter);
        setAddress(AddrKey.L2_MULTISIG, _l2Multisig);

        _mockCalls();

        ChildChainGaugeFactoryDeploy deploy = new ChildChainGaugeFactoryDeploy();
        deploy.disableDeploymentsSync();

        _factory = deploy.run();

        _feesTest = new FeesManagerTest();
    }

    /// @notice Ensure that a LiquidityGaugesFactory is deployed with the correct gauge implementation.
    function testEnsureFactoryDeployedWithCorrectData() public {
        assertEq(
            _factory.getGaugeImplementation(),
            getAddress(VeSiloContracts.CHILD_CHAIN_GAUGE),
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

    function testCreateChildChainGaugeAndVerifyGetters() public {
        ISiloChildChainGauge gauge = _createGauge();

        assertEq(gauge.hook_receiver(), _hookReceiver, "Deployed with wrong hook receiver");
        assertEq(gauge.share_token(), _shareToken, "Deployed with wrong share token");
        assertEq(gauge.silo(), _silo, "Deployed with wrong silo");
        assertEq(gauge.silo_factory(), _siloFactory, "Deployed with wrong silo factory");
        assertEq(gauge.bal_pseudo_minter(), _l2BalancerPseudoMinter, "Deployed with wrong minter");
        assertEq(gauge.voting_escrow_delegation_proxy(), _votingEscrowDelegationProxy, "Deployed with wrong proxy");
        assertEq(gauge.version(), _factory.getProductVersion(), "Deployed with wrong version");
        assertEq(address(gauge.factory()), address(_factory), "Deployed with wrong factory");

        assertEq(
            gauge.authorizer_adaptor(),
            getAddress(AddrKey.L2_MULTISIG),
            "Deployed with wrong timelockController"
        );
    }

    /// @notice Should revert if msg.sender is not hook receiver
    function testUpdateUsersPemissions() public {
        ISiloChildChainGauge gauge = _createGauge();

        vm.expectRevert(); // dev: only hook receiver
        
        gauge.afterTokenTransfer(
            _bob,
            _BOB_BAL,
            _alice,
            _ALICE_BAL,
            _TOTAL_SUPPLY,
            0 // we don't use it in the gauge
        );
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testTransferTokensToTheMinter --ffi -vvv
    function testTransferTokensToTheMinter() public {
        ISiloChildChainGauge gauge = _createGauge();

        assertEq(_siloToken.balanceOf(address(gauge)), 0, "Before. An invalid balance of the gauge");

        assertEq(
            _siloToken.balanceOf(address(_l2BalancerPseudoMinter)),
            0,
            "Before. An invalid balance of the minter"
        );

        uint256 tokensAmount = 100e18;

        // Mint tokens to the gauge. This is the same as we bridge tokens from the main chain to the child chain
        _siloToken.mint(address(gauge), tokensAmount);

        assertEq(_siloToken.balanceOf(address(gauge)), tokensAmount);

        _mockBalanceAndTotalSupply(_bob, 0,0);

        gauge.user_checkpoint(_bob);

        assertEq(_siloToken.balanceOf(address(gauge)), 0);
        assertEq(_siloToken.balanceOf(address(_l2BalancerPseudoMinter)), tokensAmount);

        // second checkpoit has no effect
        gauge.user_checkpoint(_bob);

        assertEq(_siloToken.balanceOf(address(gauge)), 0);
        assertEq(_siloToken.balanceOf(address(_l2BalancerPseudoMinter)), tokensAmount);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testAnyOneCanCheckpoint --ffi -vvv
    function testAnyOneCanCheckpoint() public {
        address someUser1 = makeAddr("Some user 1");
        address someUser2 = makeAddr("Some user 2");

        ISiloChildChainGauge gauge = _createGauge();

        _mockBalanceAndTotalSupply(_bob, _BOB_BAL, _TOTAL_SUPPLY);

        // calls hould not revert

        vm.prank(someUser1);
        gauge.user_checkpoint(_bob);

        _mockBalanceAndTotalSupply(_bob, _BOB_BAL + 1e18, _TOTAL_SUPPLY + 1e18);

        vm.prank(someUser2);
        gauge.user_checkpoint(_bob);
    }

    /// @notice Should update stats for two users
    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testUpdateUsers --ffi -vvv
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

        assertEq(gauge.working_balances(_bob), 25200000000000000000, "After 2. An invalid working balance for Bob");
        assertEq(gauge.working_balances(_alice), _ALICE_BAL, "After 2. An invalid working balance for Alice");
    }

    function _createGauge() internal returns (ISiloChildChainGauge gauge) {
        gauge = ISiloChildChainGauge(_factory.create(_shareToken));
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
            abi.encodeWithSelector(IVotingEscrowDelegationProxyLike.totalSupply.selector),
            abi.encode(_TOTAL_SUPPLY)
        );

        vm.mockCall(
            _votingEscrowDelegationProxy,
            abi.encodeWithSelector(IVotingEscrowDelegationProxyLike.adjustedBalanceOf.selector, _bob),
            abi.encode(_BOB_BAL)
        );

        vm.mockCall(
            _votingEscrowDelegationProxy,
            abi.encodeWithSelector(IVotingEscrowDelegationProxyLike.adjustedBalanceOf.selector, _alice),
            abi.encode(_ALICE_BAL)
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

    function _mockBalanceAndTotalSupply(address _user, uint256 _balance, uint256 _total) internal {
        if (_balance > _total) revert();

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.balanceOfAndTotalSupply.selector, _user),
            abi.encode(_balance, _total)
        );
    }

    function _mockMinted(address _user, address _gauge, uint256 _amount) internal {
        vm.mockCall(
            _l2BalancerPseudoMinter,
            abi.encodeWithSelector(IMinter.minted.selector, _user, _gauge),
            abi.encode(_amount)
        );
    }
}
