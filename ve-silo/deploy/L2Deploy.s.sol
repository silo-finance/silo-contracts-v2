// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {L2BalancerPseudoMinterDeploy} from "ve-silo/deploy/L2BalancerPseudoMinterDeploy.s.sol";
import {L2LayerZeroBridgeForwarderDeploy} from "ve-silo/deploy/L2LayerZeroBridgeForwarderDeploy.sol";
import {ChildChainGaugeRegistryDeploy} from "ve-silo/deploy/ChildChainGaugeRegistryDeploy.s.sol";
import {ChildChainGaugeCheckpointerDeploy} from "ve-silo/deploy/ChildChainGaugeCheckpointerDeploy.s.sol";
import {OmniVotingEscrowChildDeploy} from "ve-silo/deploy/OmniVotingEscrowChildDeploy.s.sol";
import {VeBoostDeploy} from "ve-silo/deploy/VeBoostDeploy.s.sol";
import {VotingEscrowDelegationProxyDeploy} from "ve-silo/deploy/VotingEscrowDelegationProxyDeploy.s.sol";
import {ChildChainGaugeFactoryDeploy} from "ve-silo/deploy/ChildChainGaugeFactoryDeploy.s.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/L2Deploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract L2Deploy is CommonDeploy {
    function run() public {
        L2BalancerPseudoMinterDeploy pseudeMinterDeploy = new L2BalancerPseudoMinterDeploy();
        L2LayerZeroBridgeForwarderDeploy layerZeroFrowarderDeploy = new L2LayerZeroBridgeForwarderDeploy();
        ChildChainGaugeRegistryDeploy gaugeRegistryDeploy = new ChildChainGaugeRegistryDeploy();
        ChildChainGaugeCheckpointerDeploy gaugeCheckpointerDeploy = new ChildChainGaugeCheckpointerDeploy();
        OmniVotingEscrowChildDeploy omniVEChildDeploy = new OmniVotingEscrowChildDeploy();
        VeBoostDeploy veBoostDeploy = new VeBoostDeploy();
        VotingEscrowDelegationProxyDeploy deplegationProxyDeploy = new VotingEscrowDelegationProxyDeploy();
        ChildChainGaugeFactoryDeploy gaugeFactory = new ChildChainGaugeFactoryDeploy();

        pseudeMinterDeploy.run();
        layerZeroFrowarderDeploy.run();
        gaugeRegistryDeploy.run();
        gaugeCheckpointerDeploy.run();
        omniVEChildDeploy.run();
        veBoostDeploy.run();
        deplegationProxyDeploy.run();
        gaugeFactory.run();
    }
}
