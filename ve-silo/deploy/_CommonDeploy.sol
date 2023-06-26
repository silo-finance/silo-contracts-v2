// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

contract Contracts {
    // smart contracts list
    string internal constant _VOTING_ESCROW = "VotingEscrow.vy";
    string internal constant _TIMELOCK_CONTROLLER = "TimelockController.sol";
    string internal constant _SILO_GOVERNOR = "SiloGovernor.sol";
}

contract CommonDeploy is Deployer, Contracts {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/ve-silo";
    string internal constant _DEPLOYMENTS_SUB_DIR = "ve-silo";

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return _DEPLOYMENTS_SUB_DIR;
    }
}
