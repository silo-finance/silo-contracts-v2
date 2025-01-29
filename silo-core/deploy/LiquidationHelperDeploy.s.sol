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
    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LiquidationHelperDeploy.s.sol:LiquidationHelperDeploy \
        --ffi --broadcast --rpc-url $RPC_SONIC\
        --verify

    NOTICE: remember to register it in Tower
*/
contract LiquidationHelperDeploy is CommonDeploy {
    address constant EXCHANGE_PROXY_1INCH = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address constant ODOS_ROUTER_SONIC = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D;

    address payable constant GNOSIS_SAFE_MAINNET = payable(0); // placeholder for integration tests
    address payable constant GNOSIS_SAFE_ARB = payable(0x865A1DA42d512d8854c7b0599c962F67F5A5A9d9);
    address payable constant GNOSIS_SAFE_OP = payable(0x468CD12aa9e9fe4301DB146B0f7037831B52382d);
    address payable constant GNOSIS_SAFE_SONIC = payable(0x7461d8c0fDF376c847b651D882DEa4C73fad2e4B);

    function run() public virtual returns (address liquidationHelper) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address nativeToken = _nativeToken();
        address exchangeProxy = _exchangeProxy();
        address payable tokenReceiver = _tokenReceiver();

        console2.log("[LiquidationHelperDeploy] nativeToken(): ", nativeToken);
        console2.log("[LiquidationHelperDeploy] exchangeProxy: ", exchangeProxy);
        console2.log("[LiquidationHelperDeploy] tokensReceiver: ", tokenReceiver);

        vm.startBroadcast(deployerPrivateKey);

        liquidationHelper = address(new LiquidationHelper(nativeToken, exchangeProxy, tokenReceiver));

        vm.stopBroadcast();

        _registerDeployment(liquidationHelper, SiloCoreContracts.LIQUIDATION_HELPER);
    }

    function _nativeToken() internal returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return address(1);
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return AddrLib.getAddress(AddrKey.wS);

        revert(string.concat("can not find native token for ", ChainsLib.chainAlias()));
    }

    function _exchangeProxy() internal view returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return address(2);
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return ODOS_ROUTER_SONIC;

        revert(string.concat("exchangeProxy not set for ", ChainsLib.chainAlias()));
    }

    function _tokenReceiver() internal view returns (address payable) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return payable(address(3));
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return GNOSIS_SAFE_OP;
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return GNOSIS_SAFE_ARB;
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return GNOSIS_SAFE_SONIC;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) {
            console2.log("[LiquidationHelperDeploy] TODO set _tokenReceiver for ", ChainsLib.chainAlias());
            return GNOSIS_SAFE_MAINNET;
        }

        revert(string.concat("tokenReceiver not set for ", ChainsLib.chainAlias()));
    }
}
