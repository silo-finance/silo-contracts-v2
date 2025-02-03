// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "../CommonDeploy.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {PythAggregatorFactory} from "silo-oracles/contracts/pyth/PythAggregatorFactory.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/pyth/PythAggregatorFactoryDeploy.s.sol \
        --ffi --rpc-url $RPC_URL --broadcast --verify
 */
contract PythAggregatorFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address pyth = AddrLib.getAddress("PYTH_PRICE_FEED");

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PythAggregatorFactory(pyth));

        vm.stopBroadcast();
    }
}
