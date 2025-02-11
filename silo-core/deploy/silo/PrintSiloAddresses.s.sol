// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {CommonDeploy} from "../_CommonDeploy.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

/**
FOUNDRY_PROFILE=core 
    forge script silo-core/deploy/silo/PrintSiloAddresses.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract PrintSiloAddresses is CommonDeploy {
    function run() public {
        ISiloFactory siloFactory = ISiloFactory(
            SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, ChainsLib.chainAlias())
        );

        console2.log("All Silo addresses for network", ChainsLib.chainAlias());
        uint256 i = 1;

        while (true) {
            ISiloConfig config = ISiloConfig(siloFactory.idToSiloConfig(i));
            i++;

            if (address(config) == address(0)) {
                break;
            }

            (address silo0, address silo1) = config.getSilos();
            console2.log(silo0);
            console2.log(silo1);
        }
    }
}
