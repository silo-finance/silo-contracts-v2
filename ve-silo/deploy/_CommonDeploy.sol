// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {VeSiloAddresses} from "ve-silo/common/VeSiloAddresses.sol";

contract CommonDeploy is Deployer, VeSiloAddresses {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/ve-silo";
    string internal constant _DEPLOYMENTS_SUB_DIR = "ve-silo";

    error UnsopportedNetworkForDeploy(string networkAlias);

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return _DEPLOYMENTS_SUB_DIR;
    }
}
