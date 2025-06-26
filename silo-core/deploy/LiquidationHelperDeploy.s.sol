// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {LiquidationHelper, ILiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LiquidationHelperDeploy.s.sol:LiquidationHelperDeploy \
        --ffi --rpc-url $RPC_INK \
        --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LiquidationHelperDeploy.s.sol:LiquidationHelperDeploy \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout \
        --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume

    NOTICE: remember to register it in Tower
*/
contract LiquidationHelperDeploy is CommonDeploy {
    address constant EXCHANGE_PROXY_1INCH = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address constant ODOS_ROUTER_SONIC = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D;
    address constant ENSO_ROUTER_SONIC = 0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf;
    address constant EXCHANGE_PROXY_ZERO_X_INK = 0x0000000000001fF3684f28c67538d4D072C22734;

    address payable constant GNOSIS_SAFE_MAINNET = payable(0xE8e8041cB5E3158A0829A19E014CA1cf91098554);
    address payable constant GNOSIS_SAFE_AVALANCHE = payable(0xE8e8041cB5E3158A0829A19E014CA1cf91098554);
    address payable constant GNOSIS_SAFE_ARB = payable(0x865A1DA42d512d8854c7b0599c962F67F5A5A9d9);
    address payable constant GNOSIS_SAFE_OP = payable(0x468CD12aa9e9fe4301DB146B0f7037831B52382d);
    address payable constant GNOSIS_SAFE_SONIC = payable(0x7461d8c0fDF376c847b651D882DEa4C73fad2e4B);
    address payable constant GNOSIS_SAFE_INK = payable(0xE8e8041cB5E3158A0829A19E014CA1cf91098554);

    function run() public virtual returns (address liquidationHelper) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address nativeToken = _nativeToken();
        address exchangeProxy = _exchangeProxy();
        address payable tokenReceiver = _tokenReceiver();

        console2.log("[LiquidationHelperDeploy] nativeToken(): ", nativeToken);
        console2.log("[LiquidationHelperDeploy] exchangeProxy: ", exchangeProxy);
        console2.log("[LiquidationHelperDeploy] tokenReceiver: ", tokenReceiver);

        vm.startBroadcast(deployerPrivateKey);

        liquidationHelper = address(new LiquidationHelper(nativeToken, exchangeProxy, tokenReceiver));

        vm.stopBroadcast();

        _registerDeployment(liquidationHelper, SiloCoreContracts.LIQUIDATION_HELPER);
    }

    function _exchangeProxy() internal view returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return address(2);
        if (chainId == ChainsLib.AVALANCHE_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return EXCHANGE_PROXY_1INCH;
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return ENSO_ROUTER_SONIC;
        if (chainId == ChainsLib.INK_CHAIN_ID) return EXCHANGE_PROXY_ZERO_X_INK;

        revert(string.concat("exchangeProxy not set for ", ChainsLib.chainAlias()));
    }

    function _tokenReceiver() internal view returns (address payable) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return payable(address(3));
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return GNOSIS_SAFE_OP;
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return GNOSIS_SAFE_ARB;
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return GNOSIS_SAFE_SONIC;
        if (chainId == ChainsLib.INK_CHAIN_ID) return GNOSIS_SAFE_INK;
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return GNOSIS_SAFE_MAINNET;
        if (chainId == ChainsLib.AVALANCHE_CHAIN_ID) return GNOSIS_SAFE_AVALANCHE;

        revert(string.concat("tokenReceiver not set for ", ChainsLib.chainAlias()));
    }
}
