// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {SiloVirtualAsset8Decimals} from "silo-oracles/contracts/silo-virtual-assets/SiloVirtualAsset8Decimals.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/SiloVirtualAsset8DecimalsDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloVirtualAsset8DecimalsDeploy is CommonDeploy {
    function run() public returns (address asset) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        asset = address(new SiloVirtualAsset8Decimals());

        vm.stopBroadcast();

        _registerDeployment(asset, SiloOraclesContracts.SILO_VIRTUAL_ASSET_8_DECIMALS);
    }
}
