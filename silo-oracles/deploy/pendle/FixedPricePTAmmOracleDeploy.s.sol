// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {PTAmmOracleDeployCommon} from "./deployment-helpers/PTAmmOracleDeployCommon.s.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

/**
 * FOUNDRY_PROFILE=oracles \
 * PT_TOKEN=PT_Ethena_USDe_25SEP2025 \
 * PT_UNDERLYING_QUOTE_TOKEN=USDe \
 * HARDCODED_QUOTE_TOKEN=USDC \
 *     forge script silo-oracles/deploy/pendle/FixedPricePTAmmOracleDeploy.s.sol \
 *     --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract FixedPricePTAmmOracleDeploy is PTAmmOracleDeployCommon {
    function run() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.PENDLE_FIXED_PRICE_AMM_ORACLE)),
            ptToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_TOKEN")),
            ptUnderlyingQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_UNDERLYING_QUOTE_TOKEN")),
            hardcoddedQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("HARDCODED_QUOTE_TOKEN"))
        });

        _deployPTAmmOracle(config);
    }
}
