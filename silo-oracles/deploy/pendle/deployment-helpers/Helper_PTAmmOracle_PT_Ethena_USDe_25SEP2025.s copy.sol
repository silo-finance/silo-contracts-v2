// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTAmmOracleDeployCommon} from "./PTAmmOracleDeployCommon.s.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

/**
FOUNDRY_PROFILE=oracles \
AMM=0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340 \
PT_TOKEN=0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7 \
PT_UNDERLYING_QUOTE_TOKEN=0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34 \
HARDCODED_QUOTE_TOKEN=0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E \
    forge script silo-oracles/deploy/pendle/deployment-helpers/Helper_PTAmmOracle_PT_Ethena_USDe_25SEP2025.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract Helper_PTAmmOracle_PT_Ethena_USDe_25SEP2025 is PTAmmOracleDeployCommon {
    function run() public {

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("AMM"))),
            ptToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_TOKEN")),
            ptUnderlyingQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_UNDERLYING_QUOTE_TOKEN")),
            hardcoddedQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("HARDCODED_QUOTE_TOKEN"))
        });

        run(config);
    }
}
