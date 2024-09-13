// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {L2Deploy} from "ve-silo/deploy/L2Deploy.s.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {IChildChainGaugeRegistry} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeRegistry.sol";
import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {IL2BalancerPseudoMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IL2BalancerPseudoMinter.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {VotingEscrowChildChainTest} from "ve-silo/test/voting-escrow/VotingEscrowChildChain.unit.t.sol";
import {ERC20Mint as ERC20} from "ve-silo/test/_mocks/ERC20Mint.sol";

import {
    ISiloFactoryWithFeeDetails as ISiloFactory
} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloFactoryWithFeeDetails.sol";

// solhint-disable max-states-count

// FOUNDRY_PROFILE=ve-silo-test forge test --mc L2Test --ffi -vvv
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
    address internal _l2Multisig = makeAddr(AddrKey.L2_MULTISIG);
    address internal _sender = makeAddr("Source chain sender");

    IChildChainGaugeFactory internal _factory;
    IL2BalancerPseudoMinter internal _l2PseudoMinter;
    IVotingEscrowChildChain internal _votingEscrowChild;
    VotingEscrowChildChainTest internal _votingEscrowChildTest;

    ERC20 internal _siloToken;

    bool internal _executeDeploy = true;

    function setUp() public virtual {
        if (_executeDeploy) {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            _deployer = vm.addr(deployerPrivateKey);

            // only to make deployment scripts work
            vm.createSelectFork(
                getChainRpcUrl(SEPOLIA_ALIAS),
                _FORKING_BLOCK_NUMBER
            );

            setAddress(AddrKey.L2_MULTISIG, _l2Multisig);

            _dummySiloToken();

            L2Deploy deploy = new L2Deploy();
            deploy.disableDeploymentsSync();

            deploy.run();
        } else {
            setAddress(AddrKey.L2_MULTISIG, _l2Multisig);
        }

        _factory = IChildChainGaugeFactory(getAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY));
        _l2PseudoMinter = IL2BalancerPseudoMinter(getAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER));
        _votingEscrowChild = IVotingEscrowChildChain(getAddress(VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN));

        _votingEscrowChildTest = new VotingEscrowChildChainTest();
    }

    function testChildChainIntegration() public {
        _mockSiloCoreCalls(); // mock silo core calls as it is not deployed

        // create gauges
        ISiloChildChainGauge gauge = _createGauge();

        // Register gauge factory
        vm.prank(_deployer);
        _l2PseudoMinter.addGaugeFactory(ILiquidityGaugeFactory(address(_factory)));

        // simulating voting power transfer through the CCIP
        _transferVotingPower();

        // transfer incentives (SILO token)
        _transferIncentives(gauge);

        // user checkpoint and inflation rate
        _userCheckpointAndInflationRate(gauge);

        uint256 integrateCheckpointBob = gauge.integrate_checkpoint_of(_bob);
        assertTrue(integrateCheckpointBob != 0, "User is not check pointed");

        _verifyClaimable(ISiloChildChainGauge(gauge));

        _mintIncentives(gauge);

        _verifyMintedStats(gauge);

        _rewardwsFees(gauge);
    }

    function _mintIncentives(ISiloChildChainGauge _gauge) internal {
        uint256 pseudoMinterBalance = _siloToken.balanceOf(address(_l2PseudoMinter));
        assertEq(pseudoMinterBalance, _INCENTIVES_AMOUNT, "Invalid `_l2PseudoMinter` balance");

        vm.warp(block.timestamp + 10 days);

        vm.prank(_bob);
        _l2PseudoMinter.mint(address(_gauge));

        uint256 userBalance = _siloToken.balanceOf(_bob);
        assertEq(userBalance, _EXPECTED_USER_BAL, "Expect user to receive incentives");

        uint256 claimableTotal = _gauge.claimable_tokens(_bob);

        assertEq(claimableTotal, 0, "Expect to have an empty claimable balance");
    }

    function _verifyMintedStats(ISiloChildChainGauge _gauge) internal view {
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
        gauge = ISiloChildChainGauge(_factory.create(_shareToken));
        vm.label(address(gauge), "gauge");
    }

    function _transferVotingPower() internal {
        vm.prank(_l2Multisig);
        _votingEscrowChild.setSourceChainSender(_sender);

        bytes memory data = _votingEscrowChildTest.balanceTransferData();
        Client.Any2EVMMessage memory ccipMessage = _votingEscrowChildTest.getCCIPMessage(data);

        vm.prank(getAddress(AddrKey.CHAINLINK_CCIP_ROUTER));
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

        assertNotEq(feeDao, 0, "DAO fee is zero");
        assertNotEq(feeDeployer, 0, "Deployer fee is zero");
        assertNotEq(claimableTokens, 0, "Claimable tokens are zero");

        assertTrue(claimableTotal == (claimableTokens + feeDao + feeDeployer));

        uint256 expectedFeeDao = claimableTotal * 10 / 100;
        uint256 expectedFeeDeployer = claimableTotal * 20 / 100;
        uint256 expectedToReceive = claimableTotal - expectedFeeDao - expectedFeeDeployer;

        assertEq(expectedFeeDao, feeDao, "Wrong DAO fee");
        assertEq(expectedFeeDeployer, feeDeployer, "Wrong deployer fee");
        assertEq(expectedToReceive, claimableTokens, "Wrong number of the user tokens");
    }

    function _userCheckpointAndInflationRate(ISiloChildChainGauge _gauge) internal {
        // inflation retes before the user checkpoint
        uint256 currentWeek = block.timestamp / 1 weeks;
        uint256 inflationRateBefore = _gauge.inflation_rate(currentWeek);

        uint256 siloAmountPerWeek = _siloToken.balanceOf(address(_gauge));

        // Expect to transfer all incentives to the `_l2PseudoMinter` during the user checkpoint
        _gauge.user_checkpoint(_bob);

        uint256 currentWeekTimestamp = currentWeek * 1 weeks;
        uint256 nextWeekTimestamp = currentWeekTimestamp + 1 weeks;

        uint256 expectedInflationRage = inflationRateBefore + siloAmountPerWeek / (nextWeekTimestamp - block.timestamp);

        uint256 inflationRateAfter = _gauge.inflation_rate(currentWeek);

        assertEq(inflationRateAfter, expectedInflationRage, "Inflation rate is not correct");
    }

    function _mockSiloCoreCalls() internal {
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

    function _dummySiloToken() internal {
        _siloToken = new ERC20("Silo test token", "SILO");
        setAddress(getChainId(), SILO_TOKEN, address(_siloToken));
    }

    function _rewardwsFees(ISiloChildChainGauge _gauge) internal {
        vm.prank(_deployer);
        IFeesManager(address(_factory)).setFees(_DAO_FEE, _DEPLOYER_FEE);

        uint256 rewardsAmount = 100e18;

        address distributor = makeAddr("distributor");

        ERC20 rewardToken = new ERC20("Test reward token", "TRT");
        rewardToken.mint(distributor, rewardsAmount);

        vm.prank(distributor);
        rewardToken.approve(address(_gauge), rewardsAmount);

        vm.prank(_l2Multisig);
        _gauge.add_reward(address(rewardToken), distributor);

        vm.prank(distributor);
        _gauge.deposit_reward_token(address(rewardToken), rewardsAmount);

        uint256 gaugeBalance = rewardToken.balanceOf(address(_gauge));
        uint256 daoFeeReceiverBalance = rewardToken.balanceOf(_daoFeeReceiver);
        uint256 deployerFeeReceiverBalance = rewardToken.balanceOf(_deployerFeeReceiver);

        assertEq(gaugeBalance, 70e18);
        assertEq(daoFeeReceiverBalance, 10e18);
        assertEq(deployerFeeReceiverBalance, 20e18);
    }
}
