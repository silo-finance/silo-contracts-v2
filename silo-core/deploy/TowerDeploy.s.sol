// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {Tower} from "silo-core/contracts/utils/Tower.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/TowerDeploy.s.sol:TowerDeploy \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/f1e6e6a94ddf4c138f1bd8e210d091df \
    --verify

    in case verification fail, set `ETHERSCAN_API_KEY` in env and run:
    FOUNDRY_PROFILE=core forge verify-contract \
    0x22fBF354f7E8A99673559352c63Ae022E58460dd silo-core/contracts/utils/Tower.sol:Tower \
    --chain 42161 --watch
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
