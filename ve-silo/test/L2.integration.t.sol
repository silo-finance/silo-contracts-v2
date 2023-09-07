// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {IL2LayerZeroDelegation} from "balancer-labs/v2-interfaces/liquidity-mining/IL2LayerZeroDelegation.sol";
import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";
import {IVotingEscrow} from "lz_gauges/interfaces/IVotingEscrow.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";
import {L2Deploy} from "ve-silo/deploy/L2Deploy.s.sol";
import {IERC20BalancesHandler} from "ve-silo/contracts/gauges/interfaces/IERC20BalancesHandler.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {IChildChainGaugeRegistry} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeRegistry.sol";
import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {IL2BalancerPseudoMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IL2BalancerPseudoMinter.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IOmniVotingEscrowSettings} from "ve-silo/contracts/voting-escrow/interfaces/IOmniVotingEscrowSettings.sol";
import {IOmniVotingEscrowChild} from "ve-silo/contracts/voting-escrow/interfaces/IOmniVotingEscrowChild.sol";
import {IL2LayerZeroBridgeForwarder} from "ve-silo/contracts/voting-escrow/interfaces/IL2LayerZeroBridgeForwarder.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc L2Test --ffi -vvv
contract L2Test is IntegrationTest {
    // gitmodules/lz_gauges/contracts/OmniVotingEscrow.sol:L15
    // Packet types for child chains:
    uint16 internal constant _PT_USER = 0; // user balance and total supply update
    uint16 internal constant _PT_TS = 1; // total supply update
    // https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
    uint16 internal constant _ETHEREUM_CHAIN_ID = 101;
    uint256 internal constant _FORKING_BLOCK_NUMBER = 128253340;
    uint256 internal constant _INCENTIVES_AMOUNT = 2_000_000e18;
    uint256 internal constant _EXPECTED_USER_BAL = 1999999999999999999500000;
    address internal constant _SILO_WHALE_ARB = 0xae1Eb69e880670Ca47C50C9CE712eC2B48FaC3b6;

    address internal _deployer;
    address internal _erc20BalancesHandler = makeAddr("_erc20BalancesHandler");
    address internal _omniVotingEscrow = makeAddr("OmniVotingEscrow"); // L1 sender
    address internal _bob = makeAddr("_bob");
    address internal _alice = makeAddr("_alice");
    address internal _l2Multisig = makeAddr(VeSiloAddrKey.L2_MULTISIG);

    IChildChainGaugeFactory internal _factory;
    IL2BalancerPseudoMinter internal _l2PseudoMinter;
    IChildChainGaugeRegistry internal _gaugeRegistry;
    IOmniVotingEscrowChild internal _votingEscrowChild;
    IOmniVotingEscrowSettings internal _omniVotingEscrowSettings;
    IL2LayerZeroBridgeForwarder internal _bridgeForwarder;
    IL2LayerZeroDelegation internal _checkpointer;

    IERC20 internal _siloToken;

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);

        L2Deploy deploy = new L2Deploy();
        deploy.disableDeploymentsSync();

        setAddress(VeSiloAddrKey.L2_MULTISIG, _l2Multisig);

        deploy.run();

        _factory = IChildChainGaugeFactory(getDeployedAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY));
        _l2PseudoMinter = IL2BalancerPseudoMinter(getDeployedAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER));
        _gaugeRegistry = IChildChainGaugeRegistry(getDeployedAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_REGISTRY));
        _votingEscrowChild = IOmniVotingEscrowChild(getDeployedAddress(VeSiloContracts.OMNI_VOTING_ESCROW_CHILD));
        _omniVotingEscrowSettings = IOmniVotingEscrowSettings(address(_votingEscrowChild));
        _checkpointer = IL2LayerZeroDelegation(getDeployedAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_CHECKPOINTER));

        _bridgeForwarder = IL2LayerZeroBridgeForwarder(
            getDeployedAddress(VeSiloContracts.L2_LAYER_ZERO_BRIDGE_FORWARDER)
        );

        _siloToken = IERC20(getAddress(SILO_TOKEN));
    }

    function testIt() public {
        _mockCalls();

        // create gauges
        ISiloChildChainGauge gauge = _createGauge();

        // Register gauge factory
        vm.prank(_deployer);
        _l2PseudoMinter.addGaugeFactory(ILiquidityGaugeFactory(address(_factory)));

        // register gauges in the child chain gauge registry
        vm.prank(_deployer);
        _gaugeRegistry.addGauge(IChildChainGauge(address(gauge)));

        // configure auto checkpoint on voting power transfer
        vm.prank(_deployer);
        _bridgeForwarder.setDelegation(_checkpointer);

        // transfer voting power through the OmniVotingEscrowChild
        // it should checkpoint a user
        _transferVotingPower();

        uint256 integrateCheckpointBob = gauge.integrate_checkpoint_of(_bob);
        assertTrue(integrateCheckpointBob != 0, "User is not check pointed");

        // transfer incentives (SILO token)
        // get incentives by users
        vm.prank(_SILO_WHALE_ARB);
        _siloToken.transfer(address(gauge), _INCENTIVES_AMOUNT);

        uint256 userBalance = _siloToken.balanceOf(_bob);
        assertEq(userBalance, 0, "Expect to have an empty user balance");

        uint256 pseudoMinterBalance = _siloToken.balanceOf(address(_l2PseudoMinter));
        assertEq(pseudoMinterBalance, 0, "Expect to have an empty `_l2PseudoMinter` balance");

        // Expect to transfer all incentives to the `_l2PseudoMinter` during the user checkpoint
        gauge.user_checkpoint(_bob);

        pseudoMinterBalance = _siloToken.balanceOf(address(_l2PseudoMinter));
        assertEq(pseudoMinterBalance, _INCENTIVES_AMOUNT, "Invalid `_l2PseudoMinter` balance");

        vm.warp(block.timestamp + 10 days);

        vm.prank(_bob);
        _l2PseudoMinter.mint(address(gauge));

        userBalance = _siloToken.balanceOf(_bob);
        assertEq(userBalance, _EXPECTED_USER_BAL, "Expect user to receive incentives");
    }

    function _createGauge() internal returns (ISiloChildChainGauge gauge) {
        gauge = ISiloChildChainGauge(_factory.create(_erc20BalancesHandler));
        vm.label(address(gauge), "gauge");
    }

    function _transferVotingPower() internal {
        vm.prank(_deployer);
        _omniVotingEscrowSettings.setTrustedRemoteAddress(_ETHEREUM_CHAIN_ID, abi.encodePacked(_omniVotingEscrow));

        IVotingEscrow.Point memory uPoint;
        IVotingEscrow.Point memory tsPoint;

        (uPoint, tsPoint) = _pointsForBalanceTransfer();

        uint64 nonce = 1;
        uint256 lockedEnd = block.timestamp + 365 days;
        bytes memory lzPayload = abi.encode(_PT_USER, _bob, lockedEnd, uPoint, tsPoint);

        vm.prank(getAddress(VeSiloAddrKey.LZ_ENDPOINT));
        _votingEscrowChild.lzReceive(
            _ETHEREUM_CHAIN_ID,
            abi.encodePacked(_omniVotingEscrow, _omniVotingEscrowSettings),
            nonce,
            lzPayload
        );
    }

    function _mockCalls() internal {
        vm.mockCall(
            _erc20BalancesHandler,
            abi.encodeWithSelector(IERC20BalancesHandler.balanceOf.selector, _bob),
            abi.encode(500_000e18)
        );

        vm.mockCall(
            _erc20BalancesHandler,
            abi.encodeWithSelector(IERC20BalancesHandler.totalSupply.selector),
            abi.encode(200_000_000e18)
        );

        vm.mockCall(
            _erc20BalancesHandler,
            abi.encodeWithSelector(IERC20BalancesHandler.balanceOfAndTotalSupply.selector, _bob),
            abi.encode(500_000e18, 200_000_000e18)
        );
    }

    function _pointsForBalanceTransfer() internal view returns (
        IVotingEscrow.Point memory uPoint,
        IVotingEscrow.Point memory tsPoint
    ) {
        uPoint = IVotingEscrow.Point({
            bias: 500_000e18,
            slope: 101,
            ts: block.timestamp,
            blk: 103
        });

        tsPoint = IVotingEscrow.Point({
            bias: 200_000_000e18,
            slope: 201,
            ts: block.timestamp,
            blk: 203
        });
    }
}
