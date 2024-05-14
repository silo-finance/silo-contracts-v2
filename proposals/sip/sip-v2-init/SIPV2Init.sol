// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {Proposal} from "proposals/contracts/Proposal.sol";
import {Constants} from "proposals/sip/_common/Constants.sol";

contract SIPV2Init is Proposal {
    string constant public PROPOSAL_DESCRIPTION = "Silo V2 initialization";

    function run() public override returns (uint256 proposalId) {
        string memory chainAlias = ChainsLib.chainAlias();

        address gaugeFactoryAddr = VeSiloDeployments.get(VeSiloContracts.LIQUIDITY_GAUGE_FACTORY, chainAlias);
        address gaugeAdderAddr = VeSiloDeployments.get(VeSiloContracts.GAUGE_ADDER, chainAlias);
        address ccipCheckpointerAddr = VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_CHECKPOINTER, chainAlias);

        address ccipGaugeFactoryAddr = VeSiloDeployments.get(
            VeSiloMocksContracts.CCIP_GAUGE_FACTORY_ANY_CHAIN,
            chainAlias
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
        votingEscrowCCIPRemapper.acceptOwnership();
        votingEscrowDelegationProxy.acceptOwnership();
        liquidityGaugeFactory.acceptOwnership();

        // gauge related configuration
        gaugeController.add_type(Constants._GAUGE_TYPE_ETHEREUM);
        gaugeController.add_type(Constants._GAUGE_TYPE_CHILD);
        gaugeController.set_gauge_adder(gaugeAdderAddr);

        gaugeAdder.addGaugeType(Constants._GAUGE_TYPE_ETHEREUM);
        gaugeAdder.addGaugeType(Constants._GAUGE_TYPE_CHILD);
        gaugeAdder.setGaugeFactory(gaugeFactoryAddr, Constants._GAUGE_TYPE_ETHEREUM);
        gaugeAdder.setGaugeFactory(ccipGaugeFactoryAddr, Constants._GAUGE_TYPE_CHILD);

        stakelessGaugeCheckpointerAdaptor.setStakelessGaugeCheckpointer(ccipCheckpointerAddr);

        /* PROPOSAL END */

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }
}
