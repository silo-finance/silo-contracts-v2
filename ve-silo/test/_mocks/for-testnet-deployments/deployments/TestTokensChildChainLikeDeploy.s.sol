// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

import {LINKTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/LINKTokenLike.sol";
import {SILOTokenLike} from "ve-silo/test/_mocks/for-testnet-deployments/tokens/SILOTokenLike.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/TestTokensChildChainLikeDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract TestTokensChildChainLikeDeploy is CommonDeploy {
    function run() public returns (SILOTokenLike siloToken) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        siloToken = new SILOTokenLike();

        vm.stopBroadcast();

        _registerDeployment(address(siloToken), VeSiloMocksContracts.SILO_TOKEN_LIKE);
    }
}
