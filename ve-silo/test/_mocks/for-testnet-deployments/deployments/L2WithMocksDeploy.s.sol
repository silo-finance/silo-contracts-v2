// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {L2Deploy} from "ve-silo/deploy/L2Deploy.s.sol";
import {LINKTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/LINKTokenLike.sol";
import {SILOTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/SILOTokenLike.sol";
import {CCIPRouterReceiverLike} from "ve-silo/test/_mocks/for-testnet-deployments/ccip/CCIPRouterReceiverLike.sol";
import {TestTokensChildChainLikeDeploy} from "./TestTokensChildChainLikeDeploy.s.sol";
import {CCIPRouterReceiverLikeDeploy} from "./CCIPRouterReceiverLikeDeploy.s.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/L2WithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract L2WithMocksDeploy is CommonDeploy {
    function run() public {
        TestTokensChildChainLikeDeploy tokensDeploy = new TestTokensChildChainLikeDeploy();
        CCIPRouterReceiverLikeDeploy routerDeploy = new CCIPRouterReceiverLikeDeploy();

        SILOTokenLike siloToken = tokensDeploy.run();

        setAddress(SILO_TOKEN, address(siloToken));

        CCIPRouterReceiverLike router = routerDeploy.run();

        setAddress(AddrKey.CHAINLINK_CCIP_ROUTER, address(router));

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        setAddress(VeSiloContracts.FEE_DISTRIBUTOR, deployer);

        L2Deploy l2Deploy = new L2Deploy();
        l2Deploy.votingEscrowChild().enableMainnetSimulation();
        l2Deploy.run();
    }
}
