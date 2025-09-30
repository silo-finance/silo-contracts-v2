// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {PTLinearOracleDeployCommon} from "./PTLinearOracleDeployCommon.s.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/deployment-helpers/Helper_PTLinearOracle_MAINNET_PT_USDf_29JAN2026.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract Helper_PTLinearOracle_MAINNET_PT_USDf_29JAN2026 is PTLinearOracleDeployCommon {
    function run() public {
        address pt_USDf_29JAN2026 = 0xeC3b5e45dD278d5AB9CDB31754B54DB314e9D52a;
        address market = 0xc65B7a0f8Fc97e1D548860d866f4304E039EF016;
        uint256 baseDiscountPerYear = 0.3e18;

        AggregatorV3Interface oracle = _deployPTLinearOracle(pt_USDf_29JAN2026, baseDiscountPerYear);

        _pullExchangeFactor(oracle, market, pt_USDf_29JAN2026);
    }
}

