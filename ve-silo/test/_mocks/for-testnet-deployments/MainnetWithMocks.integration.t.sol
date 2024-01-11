// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {MainnetTest} from "ve-silo/test/Mainnet.integration.t.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {MainnetWithMocksDeploy} from "./deployments/MainnetWithMocksDeploy.s.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender, CCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {InitialConfigWithMocks} from "./deployments/InitialConfigWithMocks.s.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc MainnetWithMocksIntegrationTest --ffi -vvv
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

        super.setUp();
    }

    function testTransferVotingPowerCCIP() public {
        _configureFakeSmartWalletChecker();
        _giveVeSiloTokensToUsers();

        IVeSiloDelegatorViaCCIP veSiloDelegator = IVeSiloDelegatorViaCCIP(
            getAddress(VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP)
        );

        uint64 dstChainSelector = 1; 

        vm.prank(_deployer);
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

    function testIncentivesTransferCCIP() public {
        _configureFakeSmartWalletChecker();
        _giveVeSiloTokensToUsers();

        InitialConfigWithMocks initialConfig = new InitialConfigWithMocks();
        address gauge = initialConfig.run();
        vm.label(gauge, "CCIP_Gauge");

        vm.warp(block.timestamp + 1 weeks);
        _voteForGauge(gauge);

        ICCIPGaugeCheckpointer ccipCheckpointer = ICCIPGaugeCheckpointer(
            VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_CHECKPOINTER, ChainsLib.chainAlias())
        );

        IGaugeController controller = IGaugeController(VeSiloDeployments.get(
            VeSiloContracts.GAUGE_CONTROLLER,
            ChainsLib.chainAlias()
        ));

        uint256 ethFees = ccipCheckpointer.getTotalBridgeCost(
            0,
            initialConfig.GAUGE_TYPE_CC(),
            ICCIPGauge.PayFeesIn.Native
        );

        address checkpointer = makeAddr("CCIP Gauge Checkpointer");

        controller.change_type_weight(1, 1e18);
        controller.change_type_weight(0, 1e18);

        vm.warp(block.timestamp + 2 weeks);

        vm.deal(checkpointer, ethFees);
        vm.prank(checkpointer);
        ccipCheckpointer.checkpointSingleGauge{value: ethFees}(
            initialConfig.GAUGE_TYPE_CC(),
            ICCIPGauge(gauge),
            ICCIPGauge.PayFeesIn.Native
        );
    }
}
