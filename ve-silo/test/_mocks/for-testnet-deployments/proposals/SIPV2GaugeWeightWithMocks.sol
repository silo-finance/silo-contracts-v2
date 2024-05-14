// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";
import {Constants} from "proposals/sip/_common/Constants.sol";

contract SIPV2GaugeWeightWithMocks is Proposal {
    string constant public PROPOSAL_DESCRIPTION = "Gauge type weight";

    address public gauge;
    uint256 public weight;

    function run() public override returns (uint256 proposalId) {
        /* PROPOSAL START */
        gaugeController.change_gauge_weight(gauge, weight);
        /* PROPOSAL END */

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }

    function setGauge(address _gauge) public returns (SIPV2GaugeWeightWithMocks proposal) {
        gauge = _gauge;
        proposal = this;
    }

    function setWeight(uint256 _weight) public returns (SIPV2GaugeWeightWithMocks proposal) {
        weight = _weight;
        proposal = this;
    }

    function _initializeProposers() internal override {
        initGaugeController();
    }
}
