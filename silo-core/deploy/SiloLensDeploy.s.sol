// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";
import {Tower} from "silo-core/contracts/utils/Tower.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloLensDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloLensDeploy is CommonDeploy {
    function run() public returns (ISiloLens siloLens) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        string memory chainAlias = ChainsLib.chainAlias();

        Tower tower = Tower(SiloCoreDeployments.get(SiloCoreContracts.TOWER, chainAlias));

        vm.startBroadcast(deployerPrivateKey);

        siloLens = ISiloLens(address(new SiloLens()));
        tower.update("SiloLens", address(siloLens));

        vm.stopBroadcast();

        _registerDeployment(address(siloLens), SiloCoreContracts.SILO_LENS);
    }
}
