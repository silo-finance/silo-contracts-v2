// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTLinearOracleDeployCommon} from "./deployment-helpers/PTLinearOracleDeployCommon.sol";

/**
FOUNDRY_PROFILE=oracles \
PT_TOKEN=PT-iUSD-4-NOV-25 \
PT_UNDERLYING_TOKEN=iUSD \
PT_MARKET_ADDRESS=0x6524421041a33a559831a6d305936361b6e4d217 \
BASE_DISCOUNT_PER_YEAR=0.19e18 \
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
