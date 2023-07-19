// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {AddressesCollection} from "silo-foundry-utils/networks/addresses/AddressesCollection.sol";

library VeSiloAddressesKeys {
    string constant public LZ_ENDPOINT = "LayerZero endpoint";
}

contract VeSiloAddresses is AddressesCollection {
    constructor() {
        _initializeEthereum();
        _initializeArbitrum();
    }

    function _initializeEthereum() private {
        uint256 ethChainId = getChain(MAINNET_ALIAS).chainId;

        setAddress(ethChainId, VeSiloAddressesKeys.LZ_ENDPOINT, 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
    }

    function _initializeArbitrum() private {
        uint256 arbitrumChainId = getChain(ARBITRUM_ONE_ALIAS).chainId;

        setAddress(arbitrumChainId, VeSiloAddressesKeys.LZ_ENDPOINT, 0x3c2269811836af69497E5F486A85D7316753cf62);
    }
}
