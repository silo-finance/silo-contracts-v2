// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

import {SiloOraclesFactoriesDeployments} from "./SiloOraclesFactoriesContracts.sol";

contract CommonDeploy is Deployer {
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/silo-oracles";

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return SiloOraclesFactoriesDeployments.DEPLOYMENTS_DIR;
    }
}
