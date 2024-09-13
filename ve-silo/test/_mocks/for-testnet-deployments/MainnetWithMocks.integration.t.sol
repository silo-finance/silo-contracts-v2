// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {MainnetTest} from "ve-silo/test/Mainnet.integration.t.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {MainnetWithMocksDeploy} from "./deployments/MainnetWithMocksDeploy.s.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender, CCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";
import {Constants} from "proposals/sip/_common/Constants.sol";
import {SIPV2InitWithMocks} from "./proposals/SIPV2InitWithMocks.sol";
import {SIPV2GaugeSetUpWithMocks} from "./proposals/SIPV2GaugeSetUpWithMocks.sol";
import {SIPV2GaugeWeightWithMocks} from "./proposals/SIPV2GaugeWeightWithMocks.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc MainnetWithMocksIntegrationTest --ffi -vvv
contract MainnetWithMocksIntegrationTest is MainnetTest {
    uint256 constant public ARBITRUM_FORKING_BLOCK = 169076190;

    function setUp() public override {
        // disabling `ve-silo/deploy/MainnetDeploy.s.sol` deployment
        _executeMainnetDeploy = false;

        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            ARBITRUM_FORKING_BLOCK
        );

        // deploy with mocks
        MainnetWithMocksDeploy deploy = new MainnetWithMocksDeploy();
        deploy.disableDeploymentsSync();
        deploy.run();

        _mockFeesDistributor(); // we doploy without it, so we need to mock it

        super.setUp();
    }

    function testTransferVotingPowerCCIP() public {
        _configureFakeSmartWalletChecker();
        _giveVeSiloTokensToUsers();

        IVeSiloDelegatorViaCCIP veSiloDelegator = IVeSiloDelegatorViaCCIP(
            getAddress(VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP)
        );

        uint64 dstChainSelector = 1;

        vm.prank(address(_timelock));
        veSiloDelegator.setChildChainReceiver(dstChainSelector, _deployer);

        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _deployer,
            dstChainSelector,
            ICCIPMessageSender.PayFeesIn.Native
        );

        vm.deal(_deployer, fee);
        vm.prank(_deployer);
        veSiloDelegator.sendUserBalance{value: fee}(
            _deployer,
            dstChainSelector,
            ICCIPMessageSender.PayFeesIn.Native
        );
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testIncentivesTransferCCIP --ffi -vvv
    function testIncentivesTransferCCIP() public {
        _configureFakeSmartWalletChecker();
        _giveVeSiloTokensToUsers();

        // transfer silo token ownership to the Balancer Token Admin
        address balancerTokenAdmin = getAddress(VeSiloContracts.BALANCER_TOKEN_ADMIN);
        address siloToken = getAddress(SILO_TOKEN);

        vm.prank(_deployer);
        Ownable2Step(siloToken).transferOwnership(balancerTokenAdmin);

        vm.warp(block.timestamp + 1 weeks);
        _executeInitalProposal();

        address gauge = _createCCIPGauge();

        _executeGaugeSetUpProposal(gauge);

        (ICCIPGaugeCheckpointer ccipCheckpointer, uint256 ethFees) = _checkpointerAndFees();

        // chage gauge type weight
        _executeChangeGaugeWeightProposal(gauge);

        address checkpointer = makeAddr("CCIP Gauge Checkpointer");

        vm.warp(block.timestamp + 2 weeks);

        vm.deal(checkpointer, ethFees);
        vm.prank(checkpointer);
        ccipCheckpointer.checkpointSingleGauge{value: ethFees}(
            Constants._GAUGE_TYPE_CHILD,
            ICCIPGauge(gauge),
            ICCIPGauge.PayFeesIn.Native
        );
    }

    function _createCCIPGauge() internal returns (address gauge) {
        string memory chainAlias = ChainsLib.chainAlias();

        address gaugeAdder = VeSiloDeployments.get(VeSiloContracts.GAUGE_ADDER, chainAlias);

        address gaugeFactoryAnyChainAddr = VeSiloDeployments.get(
            VeSiloMocksContracts.CCIP_GAUGE_FACTORY_ANY_CHAIN,
            chainAlias
        );

        gauge = CCIPGaugeFactory(gaugeFactoryAnyChainAddr).create(
            gaugeAdder,
            1e18 /** weight cap */,
            1 /** destination chain */
        );

        vm.label(gauge, "CCIP_Gauge");
    }

    function _mockFeesDistributor() internal {
        address feesDistributor = makeAddr("FeesDistributorMock");
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, feesDistributor);
        vm.mockCall(feesDistributor, abi.encodeWithSelector(Ownable2Step.acceptOwnership.selector), abi.encode(true));

        address uniswapSwapper = makeAddr("UniswapSwapperMock");
        AddrLib.setAddress(VeSiloContracts.UNISWAP_SWAPPER, uniswapSwapper);
        vm.mockCall(uniswapSwapper, abi.encodeWithSelector(Ownable2Step.acceptOwnership.selector), abi.encode(true));

        address feeSwapper = makeAddr("FeeSwapperMock");
        AddrLib.setAddress(VeSiloContracts.FEE_SWAPPER, feeSwapper);
        vm.mockCall(feeSwapper, abi.encodeWithSelector(Ownable2Step.acceptOwnership.selector), abi.encode(true));
    }

    function _executeInitalProposal() internal {
        SIPV2InitWithMocks initialPropsal = new SIPV2InitWithMocks();
        initialPropsal.setProposerPK(_daoVoterPK).run();

        _executeProposal(initialPropsal);
    }

    function _executeGaugeSetUpProposal(address _gauge) internal {
        SIPV2GaugeSetUpWithMocks gaugeSetUpProposal = new SIPV2GaugeSetUpWithMocks();
        gaugeSetUpProposal.setGauge(_gauge).setProposerPK(_daoVoterPK).run();

        _executeProposal(gaugeSetUpProposal);
    }

    function _executeChangeGaugeWeightProposal(address _gauge) internal {
        SIPV2GaugeWeightWithMocks gaugeWeightProposal = new SIPV2GaugeWeightWithMocks();

        gaugeWeightProposal
            .setGauge(_gauge)
            .setWeight(1e18)
            .setProposerPK(_daoVoterPK)
            .run();

        _executeProposal(gaugeWeightProposal);
    }

    function _checkpointerAndFees() internal returns (ICCIPGaugeCheckpointer ccipCheckpointer, uint256 ethFees) {
        ccipCheckpointer = ICCIPGaugeCheckpointer(
            VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_CHECKPOINTER, ChainsLib.chainAlias())
        );

        ethFees = ccipCheckpointer.getTotalBridgeCost(
            0,
            Constants._GAUGE_TYPE_CHILD,
            ICCIPGauge.PayFeesIn.Native
        );
    }
}
