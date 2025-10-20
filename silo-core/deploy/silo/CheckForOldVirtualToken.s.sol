// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/*
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/silo/CheckForOldVirtualToken.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM
 */
contract CheckForOldVirtualToken {
    function run() public view {
        ISiloConfig siloConfig = ISiloConfig(0x450e577F905902505c4478E2776187bD3725479c);
        console2.log("checking siloConfig", address(siloConfig));
        (address silo0, address silo1) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory config0 = siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory config1 = siloConfig.getConfig(silo1);

        address quote1 = ISiloOracle(config1.solvencyOracle).quoteToken();
        address quote0 = ISiloOracle(config0.solvencyOracle).quoteToken();

        console2.log("config0.solvencyOracle", config0.solvencyOracle);
        console2.log("config1.solvencyOracle", config1.solvencyOracle);

        console2.log("quoteToken 0", quote0);
        console2.log("quoteToken 1", quote1);

        address oldVirtualToken = address(0x50967dC1beB0DDCc9d5a2a911f7A0c288340B687);

        if (quote0 == oldVirtualToken) {
            console2.log("config0.solvencyOracle is SILO_VIRTUAL_USD_8_OLD");
        }

        if (quote1 == oldVirtualToken) {
            console2.log("config1.solvencyOracle is SILO_VIRTUAL_USD_8_OLD");
        }
    }
}
