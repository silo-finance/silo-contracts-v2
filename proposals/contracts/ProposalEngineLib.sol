// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Utils} from "silo-foundry-utils/lib/Utils.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {ProposalEngine} from "./ProposalEngine.sol";
import {IProposalEngine} from "./interfaces/IProposalEngine.sol";

library ProposalEngineLib {
    /// @notice Constant address of the proposal engine
    address internal constant _ENGINE_ADDR = address(uint160(uint256(keccak256("silo proposal engine"))));

    /// @notice Initialize the proposal engine contract on the `_ENGINE_ADDR`
    function initializeEngine() internal {
        bytes memory code = Utils.getCodeAt(_ENGINE_ADDR);

        if (code.length != 0) return;

        ProposalEngine deployedEngine = new ProposalEngine();

        code = Utils.getCodeAt(address(deployedEngine));

        VmLib.vm().etch(_ENGINE_ADDR, code);
        VmLib.vm().allowCheatcodes(_ENGINE_ADDR);
        VmLib.vm().label(_ENGINE_ADDR, "ProposalEngine.sol");

        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        address siloGovernor = VeSiloDeployments.get(
            VeSiloContracts.SILO_GOVERNOR,
            ChainsLib.chainAlias()
        );

        IProposalEngine(_ENGINE_ADDR).setGovernor(siloGovernor);
    }
}
