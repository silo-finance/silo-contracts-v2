// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTLinearOracleDeployCommon} from "./deployment-helpers/PTLinearOracleDeployCommon.sol";

/**
FOUNDRY_PROFILE=oracles \
PT_TOKEN=PT_thBILL_27NOV25 \
PT_UNDERLYING_TOKEN=USDC \
PT_MARKET_ADDRESS=0x4ed09847377c30aa4e74ad071e719c5814ad9ead \
BASE_DISCOUNT_PER_YEAR=0.28e18 \
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
