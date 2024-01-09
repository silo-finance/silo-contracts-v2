// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {MainnetTest} from "ve-silo/test/Mainnet.integration.t.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {MainnetWithMocksDeploy} from "./deployments/MainnetWithMocksDeploy.s.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender, CCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {InitialConfigWithMocks} from "./deployments/InitialConfigWithMocks.s.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc MainnetWithMocksIntegrationTest --ffi -vvv
contract MainnetWithMocksIntegrationTest is MainnetTest {
    function setUp() public override {
        // disabling `ve-silo/deploy/MainnetDeploy.s.sol` deployment
        _executeMainnetDeploy = false;

        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
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
        _activeteBlancerTokenAdmin();

        InitialConfigWithMocks initialConfig = new InitialConfigWithMocks();
        address gauge = initialConfig.run();

        
    }
}
