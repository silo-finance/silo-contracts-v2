// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";
import {Constants} from "proposals/sip/_common/Constants.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {console} from "forge-std/console.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/proposals/gauge-setup/SIPV2CCIPGaugeSetUp.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
*/
contract SIPV2CCIPGaugeSetUp is Proposal {
    string constant public PROPOSAL_DESCRIPTION = "CCIP gauge setup91";

    function run() public override returns (uint256 proposalId) {
        initializeActions();

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }

    function initializeActions() public {
        address gauge = VmLib.vm().envAddress("GAUGE");

        /* PROPOSAL START */
        gaugeAdder.addGauge(gauge, Constants._GAUGE_TYPE_CHILD);

        ICCIPGauge[] memory gauges = new ICCIPGauge[](1);
        gauges[0] = ICCIPGauge(gauge);

        ccipGaugeCheckpointer.addGauges(Constants._GAUGE_TYPE_CHILD, gauges);
        /* PROPOSAL END */
    }

    function _initializeProposers() internal override {
        initCCIPGaugeCheckpointer();
        initGaugeController();
        initGaugeAdder();
    }
}
