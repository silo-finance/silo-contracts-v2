// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {L2BalancerPseudoMinterDeploy} from "ve-silo/deploy/L2BalancerPseudoMinterDeploy.s.sol";
import {VeBoostDeploy} from "ve-silo/deploy/VeBoostDeploy.s.sol";
import {VotingEscrowDelegationProxyDeploy} from "ve-silo/deploy/VotingEscrowDelegationProxyDeploy.s.sol";
import {ChildChainGaugeFactoryDeploy} from "ve-silo/deploy/ChildChainGaugeFactoryDeploy.s.sol";
import {VotingEscrowChildChainDeploy} from "ve-silo/deploy/VotingEscrowChildChainDeploy.s.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/L2Deploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract L2Deploy is CommonDeploy {
    L2BalancerPseudoMinterDeploy public pseudeMinterDeploy = new L2BalancerPseudoMinterDeploy();
    VotingEscrowChildChainDeploy public votingEscrowChild = new VotingEscrowChildChainDeploy();
    VeBoostDeploy public veBoostDeploy = new VeBoostDeploy();
    VotingEscrowDelegationProxyDeploy public deplegationProxyDeploy = new VotingEscrowDelegationProxyDeploy();
    ChildChainGaugeFactoryDeploy public gaugeFactory = new ChildChainGaugeFactoryDeploy();

    function run() public {
        pseudeMinterDeploy.run();
        votingEscrowChild.run();
        veBoostDeploy.run();
        deplegationProxyDeploy.run();
        gaugeFactory.run();
    }
}
