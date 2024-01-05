// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";

contract SIPV2Init is Proposal {
    string constant public GAUGE_TYPE = "Ethereum";
    string constant public PROPOSAL_DESCRIPTION = "Silo V2 initialization";

    function run() public override returns (uint256 proposalId) {
        address gaugeFactoryAddr = VeSiloDeployments.get(
            VeSiloContracts.LIQUIDITY_GAUGE_FACTORY,
            ChainsLib.chainAlias()
        );

        address gaugeAdderAddr = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );

        /* PROPOSAL START */

        // ownership acceptance
        ccipGaugeCheckpointer.acceptOwnership();
        feeDistributor.acceptOwnership();
        gaugeAdder.acceptOwnership();
        siloFactory.acceptOwnership();
        smartWalletChecker.acceptOwnership();
        stakelessGaugeCheckpointerAdaptor.acceptOwnership();
        uniswapSwapper.acceptOwnership();
        veSiloDelegatorViaCCIP.acceptOwnership();
        votingEscrowCCIPRemapper.acceptOwnership();
        votingEscrowDelegationProxy.acceptOwnership();

        // gauge related configuration
        gaugeController.add_type(GAUGE_TYPE);
        gaugeController.set_gauge_adder(gaugeAdderAddr);

        gaugeAdder.addGaugeType(GAUGE_TYPE);
        gaugeAdder.setGaugeFactory(gaugeFactoryAddr, GAUGE_TYPE);

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }
}
