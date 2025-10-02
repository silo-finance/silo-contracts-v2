// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {PTLinearOracleDeployCommon} from "./PTLinearOracleDeployCommon.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/deployment-helpers/Helper_PTLinearOracle_MAINNET_PT_siUSD_9oct2025.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract Helper_PTLinearOracle_MAINNET_PT_siUSD_9oct2025 is PTLinearOracleDeployCommon {
    function run() public {
        address pt_InfiniFi_siUSD_9OCT2025 =
            AddrLib.getAddress(ChainsLib.chainAlias(), "PT-PendleInfiniFi-siUSD-9OCT2025");
        address market = 0x50700eEDdE7850B4bf83733C66b272C6CA46c663;
        uint256 baseDiscountPerYear = 0.28e18;
        address undelyingToken = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.USDC);

        _verifyMarket(market, pt_InfiniFi_siUSD_9OCT2025, undelyingToken);

        _deployPTLinearOracle(pt_InfiniFi_siUSD_9OCT2025, baseDiscountPerYear);
    }
}
