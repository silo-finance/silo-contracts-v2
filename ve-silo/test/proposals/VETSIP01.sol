// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";

contract VETSIP01 is Proposal {
    string constant public GAUGE_KEY = "Test gauge";
    string constant public GAUGE_TYPE = "Mainnet gauge";
    string constant public PROPOSAL_DESCRIPTION = "Gauge configuration";

    function run() public override returns (uint256 proposalId) {
        address gauge = AddrLib.getAddress(GAUGE_KEY);

        address gaugeFactoryAddr = VeSiloDeployments.get(
            VeSiloContracts.LIQUIDITY_GAUGE_FACTORY,
            ChainsLib.chainAlias()
        );

        address gaugeAdderAddr = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );

        /* PROPOSAL START */
        gaugeController.add_type(GAUGE_TYPE);
        gaugeController.set_gauge_adder(gaugeAdderAddr);

        gaugeAdder.acceptOwnership();
        gaugeAdder.addGaugeType(GAUGE_TYPE);
        gaugeAdder.setGaugeFactory(gaugeFactoryAddr, GAUGE_TYPE);
        gaugeAdder.addGauge(gauge, GAUGE_TYPE);

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }
}
