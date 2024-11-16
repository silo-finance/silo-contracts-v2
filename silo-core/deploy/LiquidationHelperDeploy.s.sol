// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {LiquidationHelper, ILiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
    LIQUIDATION_HELPER_EXCHANGE_PROXY= \
    LIQUIDATION_HELPER_TOKENS_RECEIVER= \
        forge script silo-core/deploy/LiquidationHelperDeploy.s.sol:LiquidationHelperDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify
 */
contract LiquidationHelperDeploy is CommonDeploy {
    function run() public returns (ILiquidationHelper liquidationHelper) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address exchangeProxy = vm.envAddress("LIQUIDATION_HELPER_EXCHANGE_PROXY");
        address payable tokensReceiver = payable(vm.envAddress("LIQUIDATION_HELPER_TOKENS_RECEIVER"));

        console2.log("[LiquidationHelperDeploy] exchangeProxy: ", exchangeProxy);
        console2.log("[LiquidationHelperDeploy] tokensReceiver: ", tokensReceiver);
        console2.log("[LiquidationHelperDeploy] nativeToken(): ", nativeToken());

        vm.startBroadcast(deployerPrivateKey);

        liquidationHelper = new LiquidationHelper(nativeToken(), exchangeProxy, tokensReceiver);

        vm.stopBroadcast();

        _registerDeployment(address(liquidationHelper), SiloCoreContracts.LIQUIDATION_HELPER);
    }

    function nativeToken() private returns (address) {
        uint256 chainId = getChainId();

        if (chainId == 31337) return address(1); // anvil
        if (chainId == 1) return AddrLib.getAddress(AddrKey.WETH);
        // if (chainId == arbitrum) return AddrLib.getAddress(AddrKey.WETH);

        revert(string.concat("can not find native token for", getChainAlias()));
    }
}
