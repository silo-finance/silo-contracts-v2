// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {CommonDeploy} from "silo-core/deploy/_CommonDeploy.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

/**
FOUNDRY_PROFILE=core \
    forge script silo-core/scripts/PrintSiloAddresses.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract PrintSiloAddresses is CommonDeploy {
    ISiloConfig[] productionSiloConfigs;

    function run() public {
        console2.log("Network:", ChainsLib.chainAlias());
        saveProductionSiloConfigs();

        for (uint256 i; i < productionSiloConfigs.length; i++) {
            printConfigAndSilos(productionSiloConfigs[i]);
        }
    }

    function saveProductionSiloConfigs() internal {
        string memory root = vm.projectRoot();
        string memory abiPath = string.concat(root, "/silo-core/deploy/silo/_siloDeployments.json");
        string memory siloDeploymentsJson = vm.readFile(abiPath);
        string memory chainAlias = ChainsLib.chainAlias();
        string[] memory siloConfigNames = vm.parseJsonKeys(siloDeploymentsJson, string.concat(".", chainAlias));

        for (uint256 i = 0; i < siloConfigNames.length; i++) {
            // jsonpath-rust throws when json key has dot. ['key.with.dots'] is a workaround to define
            // the key with dots, for example, "Silo_stS_USDC.e"
            bytes memory siloConfigBytes = vm.parseJson(
                siloDeploymentsJson,
                string(abi.encodePacked(".", chainAlias, ".['", siloConfigNames[i], "']"))
            );

            address siloConfig = abi.decode(siloConfigBytes, (address));
            productionSiloConfigs.push(ISiloConfig(siloConfig));
        }
    }

    function printConfigAndSilos(ISiloConfig _config) internal view {
        console2.log(address(_config));
        (address silo0, address silo1) = _config.getSilos();
        console2.log(silo0);
        console2.log(silo1);
    }
}
