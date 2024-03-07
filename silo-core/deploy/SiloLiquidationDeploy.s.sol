// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";

import {SiloLiquidation, ISiloLiquidation} from "silo-core/contracts/SiloLiquidation.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloLiquidationDeploy.s.sol:SiloLiquidationDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloLiquidationDeploy is CommonDeploy {
    function run() public returns (ISiloLiquidation siloLiquidation) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        siloLiquidation = ISiloLiquidation(address(new SiloLiquidation()));

        vm.stopBroadcast();

        _registerDeployment(address(siloLiquidation), SiloCoreContracts.SILO_LIQUIDATION);
    }
}
