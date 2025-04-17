// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {Tower} from "silo-core/contracts/utils/Tower.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/TowerRegistration.s.sol:TowerRegistration \
    --ffi --rpc-url $RPC_SONIC --broadcast
 */
contract TowerRegistration is CommonDeploy {
    function run() public {
        _register("SiloFactory", getDeployedAddress(SiloCoreContracts.SILO_FACTORY));
        _register("LiquidationHelper", getDeployedAddress(SiloCoreContracts.LIQUIDATION_HELPER));
        _register("SiloLens", getDeployedAddress(SiloCoreContracts.SILO_LENS));
    }

    function _register(string memory _name, address _currentAddress) internal {
        Tower tower = Tower(getDeployedAddress(SiloCoreContracts.TOWER));
        address old = tower.coordinates(_name);

        if (old == _currentAddress) {
            console2.log("[TowerRegistration] %s up to date", _name);
        } else {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            console2.log("[TowerRegistration] %s will be updated from %s to %s", _name, old, _currentAddress);

            vm.startBroadcast(deployerPrivateKey);

            tower.update(_name, _currentAddress);

            vm.stopBroadcast();
        }
    }
}
