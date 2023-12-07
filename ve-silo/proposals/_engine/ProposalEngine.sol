// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IProposalEngine} from "./interfaces/IProposalEngine.sol";

contract ProposalEngine is IProposalEngine {
    struct ProposalAction {
        address target;
        uint256 value;
        bytes input;
    }

    ISiloGovernor public siloGovernor;
    ProposalAction[] public proposalActions;

    function addAction(address _target, uint256 _value, bytes calldata _input) external {
        proposalActions.push(ProposalAction({
            target: _target,
            value: _value,
            input: _input
        }));
    }

    function setGovernor(address _governor) external {
        siloGovernor = ISiloGovernor(_governor);
    }

    function executeProposal(string memory _description) external returns (uint256 proposalId) {
        uint256 actionsLength = proposalActions.length;

        address[] memory targets = new address[](actionsLength);
        uint256[] memory values = new uint256[](actionsLength);
        bytes[] memory calldatas = new bytes[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            targets[0] = proposalActions[i].target;
            values[0] = proposalActions[i].value;
            calldatas[0] = proposalActions[i].input;
        }

        uint256 proposerPrivateKey = uint256(VmLib.vm().envBytes32("PROPOSER_PRIVATE_KEY"));

        VmLib.vm().startBroadcast(deployerPrivateKey);

        proposalId = _siloGovernor.propose(
            targets,
            values,
            calldatas,
            _description
        );

        VmLib.vm().stopBroadcast();

        delete proposalActions;
    }
}
