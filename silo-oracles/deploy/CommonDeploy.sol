// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

import {SiloOraclesDeployments} from "./SiloOraclesContracts.sol";

contract CommonDeploy is Deployer {
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/silo-oracles";

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return SiloOraclesDeployments.DEPLOYMENTS_DIR;
    }
}
