// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrKey} from "common/addresses/AddrKey.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";


import {PTLinearOracleDeployCommon} from "./PTLinearOracleDeployCommon.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/deployment-helpers/Helper_PTLinearOracle_ARBITRUM_PT_sUSDai_19NOV25.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract Helper_PTLinearOracle_ARBITRUM_PT_sUSDai_19NOV25 is PTLinearOracleDeployCommon {
    function run() public {
        address pt_sUSDai_19NOV25 = 0x936F210d277bf489A3211CeF9AB4BC47a7B69C96;
        address market = 0x43023675c804A759cBf900Da83DBcc97ee2afbe7;
        uint256 baseDiscountPerYear = 0.25e18;
        address undelyingToken = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.USDai);

        _verifyMarket(market, pt_sUSDai_19NOV25, undelyingToken);

        _deployPTLinearOracle(pt_sUSDai_19NOV25, baseDiscountPerYear);
    }
}
