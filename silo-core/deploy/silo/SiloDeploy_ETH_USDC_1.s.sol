// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SiloCommonDeploy} from "./SiloCommonDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/silo/SiloDeploy1.s.sol:SiloDeploy1 \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDeploy_ETH_USDC_1 is SiloCommonDeploy {
    function siloToDeploy() public pure override returns (string memory) {
        return "ETH-USDC_UniswapV3_Silo";
    }
}
