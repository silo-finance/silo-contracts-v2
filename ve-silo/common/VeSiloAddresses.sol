// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {AddressesCollection} from "silo-foundry-utils/networks/addresses/AddressesCollection.sol";

library VeSiloAddrKey {
    string constant public ARBITRUM_GATEWAY_ROUTER = "Arbitrum gateway router";
    string constant public WETH = "WETH";
    string constant public BALANCER_VAULT = "Balancer Vault";
    string constant public UNISWAP_ROUTER = "Uniswap router";
    string constant public SNX = "Token(SNX)";
    string constant public USDC = "Token(USDC)";
    string constant public SNX_USDC_UNIV3_POOL = "SNX/USDC UniswapV3 pool";
    string constant public USDC_ETH_UNI_POOL = "USDC/ETH Uniswap pool";
    string constant public LZ_ENDPOINT = "LayerZero endpoint";
    string constant public L2_MULTISIG = "L2 Multisig";
}

contract VeSiloAddresses is AddressesCollection {
    // chain id => is initialized
    mapping(uint256 => bool) private isInitialized;

    constructor() {
        _ethereumAddresses();
        _initializeArbitrum();
    }

    function _ethereumAddresses() internal {
        uint256 chainId = getChain(MAINNET_ALIAS).chainId;

        if (isInitialized[chainId]) return;

        setAddress(chainId, VeSiloAddrKey.ARBITRUM_GATEWAY_ROUTER, 0xC840838Bc438d73C16c2f8b22D2Ce3669963cD48);
        setAddress(chainId, VeSiloAddrKey.WETH, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        setAddress(chainId, VeSiloAddrKey.BALANCER_VAULT, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        setAddress(chainId, VeSiloAddrKey.UNISWAP_ROUTER, 0xE592427A0AEce92De3Edee1F18E0157C05861564);
        setAddress(chainId, VeSiloAddrKey.SNX, 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F);
        setAddress(chainId, VeSiloAddrKey.USDC, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        setAddress(chainId, VeSiloAddrKey.SNX_USDC_UNIV3_POOL, 0x020C349A0541D76C16F501Abc6B2E9c98AdAe892);
        setAddress(chainId, VeSiloAddrKey.USDC_ETH_UNI_POOL, 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
        setAddress(chainId, VeSiloAddrKey.LZ_ENDPOINT, 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        isInitialized[chainId] = true;
    }

    function _initializeArbitrum() private {
        uint256 chainId = getChain(ARBITRUM_ONE_ALIAS).chainId;

        if (isInitialized[chainId]) return;

        setAddress(chainId, VeSiloAddrKey.LZ_ENDPOINT, 0x3c2269811836af69497E5F486A85D7316753cf62);
        setAddress(chainId, SILO_TOKEN, 0x0341C0C0ec423328621788d4854119B97f44E391);

        isInitialized[chainId] = true;
    }
}
