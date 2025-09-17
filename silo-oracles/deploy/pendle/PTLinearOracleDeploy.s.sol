// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTLinearOracleDeployCommon} from "./deployment-helpers/PTLinearOracleDeployCommon.sol";

/**
FOUNDRY_PROFILE=oracles \
PT_TOKEN=PT-sUSDf-29JAN2026 \
PT_UNDERLYING_TOKEN=USDf \
PT_MARKET_ADDRESS=0xeb5819b31a0378407f43aba2f3e9d16b40aa5ec7 \
BASE_DISCOUNT_PER_YEAR=0.35e18 \
    forge script silo-oracles/deploy/pendle/PTLinearOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract PTLinearOracleDeploy is PTLinearOracleDeployCommon {
    function run() public {
        address ptToken = AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_TOKEN"));
        address market = vm.envAddress("PT_MARKET_ADDRESS");
        uint256 baseDiscountPerYear = vm.envUint("BASE_DISCOUNT_PER_YEAR");
        address undelyingToken = AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_UNDERLYING_TOKEN"));

        _verifyMarket(market, ptToken, undelyingToken);

        _deployPTLinearOracle(ptToken, baseDiscountPerYear);
    }
}
