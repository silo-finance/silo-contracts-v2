// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

contract CommonDeploy is Deployer {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/ve-silo";

    error UnsopportedNetworkForDeploy(string networkAlias);

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return VeSiloDeployments.DEPLOYMENTS_DIR;
    }
}
