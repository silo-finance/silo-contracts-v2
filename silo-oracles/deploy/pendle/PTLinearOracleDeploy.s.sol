// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTLinearOracleDeployCommon} from "./deployment-helpers/PTLinearOracleDeployCommon.sol";

/**
FOUNDRY_PROFILE=oracles \
PT_TOKEN=PT-wstUSR-26JAN2026 \
PT_UNDERLYING_TOKEN=wstUSR \
PT_MARKET_ADDRESS=0x39c3f8e0e7c6f44dc8f0397feb124517ba82e26e \
BASE_DISCOUNT_PER_YEAR=0.25e18 \
    forge script silo-oracles/deploy/pendle/PTLinearOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
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
