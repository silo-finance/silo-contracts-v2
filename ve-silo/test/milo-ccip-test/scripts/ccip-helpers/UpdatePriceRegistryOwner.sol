// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";

import {Script} from "forge-std/Script.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/ccip-helpers/UpdatePriceRegistryOwner.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UpdatePriceRegistryOwner is Script {
    using stdStorage for StdStorage;
 
    address internal constant _CHAINLINK_PRICE_FEED = 0x13015e4E6f839E1Aa1016DF521ea458ecA20438c;

    function run() external returns (address owner, address proposer) {
        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));
        proposer = vm.addr(proposerPrivateKey);

        stdstore
            .target(_CHAINLINK_PRICE_FEED)
            .sig(IExtendedOwnable.owner.selector)
            .checked_write(proposer);

        owner = IExtendedOwnable(_CHAINLINK_PRICE_FEED).owner();
    }
}
