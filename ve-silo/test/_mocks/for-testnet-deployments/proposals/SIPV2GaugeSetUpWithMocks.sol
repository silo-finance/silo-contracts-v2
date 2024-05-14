// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";
import {Constants} from "proposals/sip/_common/Constants.sol";

contract SIPV2GaugeSetUpWithMocks is Proposal {
    string constant public PROPOSAL_DESCRIPTION = "Gauge setup with mocks";

    address public gauge;

    function run() public override returns (uint256 proposalId) {
        /* PROPOSAL START */
        ICCIPGauge[] memory gauges = new ICCIPGauge[](1);
        gauges[0] = ICCIPGauge(gauge);

        gaugeAdder.addGauge(gauge, Constants._GAUGE_TYPE_CHILD);
        ccipGaugeCheckpointer.addGauges(Constants._GAUGE_TYPE_CHILD, gauges);

        /* PROPOSAL END */

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }

    function setGauge(address _gauge) public returns (Proposal proposal) {
        gauge = _gauge;
        proposal = this;
    }

    function _initializeProposers() internal override {
        initCCIPGaugeCheckpointer();
        initGaugeAdder();
    }
}
