// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {LiquidationHelper, ILiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LiquidationHelperDeploy.s.sol:LiquidationHelperDeploy \
        --ffi --broadcast --rpc-url $RPC_ARBITRUM \
        --verify
*/
contract LiquidationHelperDeploy is CommonDeploy {
    address constant EXCHANGE_PROXY_1INCH = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    address payable constant GNOSIS_SAFE_MAINNET = payable(0); // placeholder for integration tests
    address payable constant GNOSIS_SAFE_ARB = payable(0x865A1DA42d512d8854c7b0599c962F67F5A5A9d9) ;
    address payable constant GNOSIS_SAFE_OP = payable(0x468CD12aa9e9fe4301DB146B0f7037831B52382d) ;

    function run() public returns (ILiquidationHelper liquidationHelper) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address nativeToken = _nativeToken();
        address exchangeProxy = _exchangeProxy();
        address payable tokenReceiver = _tokenReceiver();

        console2.log("[LiquidationHelperDeploy] nativeToken(): ", nativeToken);
        console2.log("[LiquidationHelperDeploy] exchangeProxy: ", exchangeProxy);
        console2.log("[LiquidationHelperDeploy] tokensReceiver: ", tokenReceiver);

        vm.startBroadcast(deployerPrivateKey);

        liquidationHelper = new LiquidationHelper(nativeToken, exchangeProxy, tokenReceiver);

        vm.stopBroadcast();

        _registerDeployment(address(liquidationHelper), SiloCoreContracts.LIQUIDATION_HELPER);
    }

    function _nativeToken() private returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return address(1);
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);

        revert(string.concat("can not find native token for ", getChainAlias()));
    }

    function _exchangeProxy() private returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return address(2);
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return EXCHANGE_PROXY_1INCH;

        revert(string.concat("exchangeProxy not set for ", getChainAlias()));
    }

    function _tokenReceiver() private returns (address payable) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return payable(address(3));
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return GNOSIS_SAFE_OP;
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return GNOSIS_SAFE_ARB;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) {
            console2.log("[LiquidationHelperDeploy] TODO set _tokenReceiver for ", getChainAlias());
            return GNOSIS_SAFE_MAINNET;
        }

        revert(string.concat("tokenReceiver not set for ", getChainAlias()));
    }
}
