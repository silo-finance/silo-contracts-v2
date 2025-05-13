// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

import {XSiloDeployments} from "x-silo/deploy/XSiloContracts.sol";

contract CommonDeploy is Deployer {
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/x-silo";

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return XSiloDeployments.DEPLOYMENTS_DIR;
    }
}
