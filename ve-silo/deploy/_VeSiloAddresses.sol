// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {AddressesCollection} from "silo-foundry-utils/networks/addresses/AddressesCollection.sol";

contract VeSiloAddresses is AddressesCollection {
    string constant public LZ_ENDPOINT = "LayerZero endpoint";

    constructor() {
        _initializeEthereum();
    }

    function _initializeEthereum() private {
        uint256 ethChainId = getChain(MAINNET_ALIAS).chainId;

        setAddress(ethChainId, LZ_ENDPOINT, 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
    }
}
