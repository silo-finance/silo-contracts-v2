// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PTAmmOracleDeployCommon} from "./PTAmmOracleDeployCommon.s.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/deployment-helpers/Helper_PTAmmOracle_PT_Ethena_USDe_25SEP2025.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract Helper_PTAmmOracle_PT_Ethena_USDe_25SEP2025 is PTAmmOracleDeployCommon {
    function run() public {

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            ptToken: 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7,
            ptUnderlyingQuoteToken: 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34,
            hardcoddedQuoteToken: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E // USDC
        });

        run(config);
    }
}
