// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy} from "ve-silo/deploy/_CommonDeploy.sol";
import {MainnetDeploy} from "ve-silo/deploy/MainnetDeploy.s.sol";
import {BPTTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/BPTTokenLike.sol";
import {LINKTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/LINKTokenLike.sol";
import {SILOTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/SILOTokenLike.sol";
import {CCIPRouterClientLike} from "ve-silo/test/_mocks/for-testnet-deployments/ccip/CCIPRouterClientLike.sol";
import {TestTokensMainnetLikeDeploy} from "./TestTokensMainnetLikeDeploy.s.sol";
import {CCIPRouterClientLikeDeploy} from "./CCIPRouterClientLikeDeploy.s.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/MainnetWithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetWithMocksDeploy is CommonDeploy {
    function run() public {
        TestTokensMainnetLikeDeploy tokensDeploy = new TestTokensMainnetLikeDeploy();
        CCIPRouterClientLikeDeploy routerDeploy = new CCIPRouterClientLikeDeploy();

        (BPTTokenLike bptToken, LINKTokenLike linkToken, SILOTokenLike siloToken) = tokensDeploy.run();

        setAddress(AddrKey.LINK, address(linkToken));
        setAddress(AddrKey.SILO_TOKEN, address(siloToken));
        setAddress(SILO80_WETH20_TOKEN, address(bptToken));

        CCIPRouterClientLike router = routerDeploy.run();

        setAddress(AddrKey.CHAINLINK_CCIP_ROUTER, address(router));

        MainnetDeploy mainnetDeploy = new MainnetDeploy();
        mainnetDeploy.enableMainnetSimulation();

        mainnetDeploy.run();
    }
}
