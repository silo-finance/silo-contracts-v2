// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {Tower} from "silo-core/contracts/utils/Tower.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/TowerDeploy.s.sol:TowerDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify
 */
contract TowerDeploy is CommonDeploy {
    function run() public returns (Tower tower) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        tower = new Tower();

        vm.stopBroadcast();

        _registerDeployment(address(tower), SiloCoreContracts.TOWER);
    }
}
