// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {ERC20 as ERC20WithoutMint, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";
import {L2Deploy} from "ve-silo/deploy/L2Deploy.s.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {IChildChainGaugeRegistry} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeRegistry.sol";
import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {IL2BalancerPseudoMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IL2BalancerPseudoMinter.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IHookReceiverMock as IHookReceiver} from "./_mocks/IHookReceiverMock.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {VotingEscrowChildChainTest} from "ve-silo/test/voting-escrow/VotingEscrowChildChain.unit.t.sol";

import {
    ISiloFactoryWithFeeDetails as ISiloFactory
} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloFactoryWithFeeDetails.sol";

// solhint-disable max-states-count

contract ERC20 is ERC20WithoutMint {
    constructor(string memory name, string memory symbol) ERC20WithoutMint(name, symbol) {}
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}

// FOUNDRY_PROFILE=ve-silo forge test --mc L2Test --ffi -vvv
contract L2Test is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 4413530;
    uint256 internal constant _INCENTIVES_AMOUNT = 2_000_000e18;
    uint256 internal constant _EXPECTED_USER_BAL = 1399999999999999999650000;
    address internal constant _SILO_WHALE_ARB = 0xae1Eb69e880670Ca47C50C9CE712eC2B48FaC3b6;
    uint256 internal constant _WEEK = 604800;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    address internal _deployer;
    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _daoFeeReceiver = makeAddr("DAO fee receiver");
    address internal _deployerFeeReceiver = makeAddr("Deployer fee receiver");
    address internal _bob = makeAddr("localUser");
    address internal _alice = makeAddr("_alice");
    address internal _l2Multisig = makeAddr(VeSiloAddrKey.L2_MULTISIG);
    address internal _sender = makeAddr("Source chain sender");

    IChildChainGaugeFactory internal _factory;
    IL2BalancerPseudoMinter internal _l2PseudoMinter;
    IVotingEscrowChildChain internal _votingEscrowChild;
    VotingEscrowChildChainTest internal _votingEscrowChildTest;

    ERC20 internal _siloToken;

    function setUp() public {
        // only to make deployment scripts work
        vm.createSelectFork(
            getChainRpcUrl(SEPOLIA_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);

        _dummySiloToken();

        L2Deploy deploy = new L2Deploy();
        deploy.disableDeploymentsSync();

        setAddress(VeSiloAddrKey.L2_MULTISIG, _l2Multisig);

        deploy.run();

        _factory = IChildChainGaugeFactory(getDeployedAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY));
        _l2PseudoMinter = IL2BalancerPseudoMinter(getDeployedAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER));
        _votingEscrowChild = IVotingEscrowChildChain(getDeployedAddress(VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN));

        _votingEscrowChildTest = new VotingEscrowChildChainTest();
    }

    function testIt() public {
        _mockCalls();

        // create gauges
        ISiloChildChainGauge gauge = _createGauge();

        // Register gauge factory
        vm.prank(_deployer);
        _l2PseudoMinter.addGaugeFactory(ILiquidityGaugeFactory(address(_factory)));

        // simulating voting power transfer through the CCIP
        _transferVotingPower();

        // transfer incentives (SILO token)
        _transferIncentives(gauge);

        // Expect to transfer all incentives to the `_l2PseudoMinter` during the user checkpoint
        gauge.user_checkpoint(_bob);

        uint256 integrateCheckpointBob = gauge.integrate_checkpoint_of(_bob);
        assertTrue(integrateCheckpointBob != 0, "User is not check pointed");

        _verifyClaimable(ISiloChildChainGauge(gauge));

        uint256 pseudoMinterBalance = _siloToken.balanceOf(address(_l2PseudoMinter));
        assertEq(pseudoMinterBalance, _INCENTIVES_AMOUNT, "Invalid `_l2PseudoMinter` balance");

        vm.warp(block.timestamp + 10 days);

        vm.prank(_bob);
        _l2PseudoMinter.mint(address(gauge));

        uint256 userBalance = _siloToken.balanceOf(_bob);
        assertEq(userBalance, _EXPECTED_USER_BAL, "Expect user to receive incentives");

        _verifyMintedStats(gauge);
    }

    function _verifyMintedStats(ISiloChildChainGauge _gauge) internal {
        uint256 totalMinted = _l2PseudoMinter.minted(_bob, address(_gauge));
        uint256 expectedMinted = totalMinted - (totalMinted * 10 / 100 + totalMinted * 20 / 100);
        uint256 mintedToUser = _l2PseudoMinter.mintedToUser(_bob, address(_gauge));

        assertEq(mintedToUser, expectedMinted, "Counters of minted tokens did not mutch");
    }

    function _transferIncentives(ISiloChildChainGauge _gauge) internal {
        _siloToken.mint(address(_gauge), _INCENTIVES_AMOUNT);

        uint256 userBalance = _siloToken.balanceOf(_bob);
        assertEq(userBalance, 0, "Expect to have an empty user balance");

        uint256 pseudoMinterBalance = _siloToken.balanceOf(address(_l2PseudoMinter));
        assertEq(pseudoMinterBalance, 0, "Expect to have an empty `_l2PseudoMinter` balance");
    }

    function _createGauge() internal returns (ISiloChildChainGauge gauge) {
        gauge = ISiloChildChainGauge(_factory.create(_hookReceiver));
        vm.label(address(gauge), "gauge");
    }

    function _transferVotingPower() internal {
        vm.prank(_deployer);
        _votingEscrowChild.setSourceChainSender(_sender);

        bytes memory data = _votingEscrowChildTest.balanceTransferData();
        Client.Any2EVMMessage memory ccipMessage = _votingEscrowChildTest.getCCIPMessage(data);

        vm.prank(getAddress(VeSiloAddrKey.CHAINLINK_CCIP_ROUTER));
        _votingEscrowChild.ccipReceive(ccipMessage);

        (,,uint256 ts,) = _votingEscrowChildTest.tsTestPoint();
        vm.warp(ts);
    }

    function _verifyClaimable(ISiloChildChainGauge _gauge) internal {
        // with fees
        // 10% - to DAO
        // 20% - to deployer
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                _daoFeeReceiver,
                _deployerFeeReceiver
            )
        );

        vm.prank(_deployer);
        IFeesManager(address(_l2PseudoMinter)).setFees(_DAO_FEE, _DEPLOYER_FEE);

        vm.warp(block.timestamp + _WEEK + 1);

        uint256 claimableTotal;
        uint256 claimableTokens;
        uint256 feeDao;
        uint256 feeDeployer;

        claimableTotal = _gauge.claimable_tokens(_bob);
        (claimableTokens, feeDao, feeDeployer) = _gauge.claimable_tokens_with_fees(_bob);

        assertTrue(claimableTotal == (claimableTokens + feeDao + feeDeployer));

        uint256 expectedFeeDao = claimableTotal * 10 / 100;
        uint256 expectedFeeDeployer = claimableTotal * 20 / 100;
        uint256 expectedToReceive = claimableTotal - expectedFeeDao - expectedFeeDeployer;

        assertEq(expectedFeeDao, feeDao, "Wrong DAO fee");
        assertEq(expectedFeeDeployer, feeDeployer, "Wrong deployer fee");
        assertEq(expectedToReceive, claimableTokens, "Wrong number of the user tokens");
    }

    function _mockCalls() internal {
        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.balanceOf.selector, _bob),
            abi.encode(500_000e18)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.totalSupply.selector),
            abi.encode(200_000_000e18)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.balanceOfAndTotalSupply.selector, _bob),
            abi.encode(500_000e18, 200_000_000e18)
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

    function _dummySiloToken() internal {
        _siloToken = new ERC20("Silo test token", "SILO");
        setAddress(getChainId(), SILO_TOKEN, address(_siloToken));
    }
}
