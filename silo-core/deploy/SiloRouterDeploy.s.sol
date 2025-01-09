// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloRouter} from "silo-core/contracts/SiloRouter.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloRouterDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify
 */
contract SiloRouterDeploy is CommonDeploy {
    function run() public returns (SiloRouter siloRouter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address nativeToken = _nativeToken();

        vm.startBroadcast(deployerPrivateKey);

        siloRouter = new SiloRouter(nativeToken);

        vm.stopBroadcast();

        _registerDeployment(address(siloRouter), SiloCoreContracts.SILO_ROUTER);
    }

    function _nativeToken() private returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return AddrLib.getAddress(AddrKey.wS);

        revert(string.concat("can not find native token for ", getChainAlias()));
    }
}
