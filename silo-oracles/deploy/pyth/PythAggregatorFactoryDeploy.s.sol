// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "../CommonDeploy.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {PythAggregatorFactory} from "silo-oracles/contracts/pyth/PythAggregatorFactory.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/pyth/PythAggregatorFactoryDeploy.s.sol \
        --ffi --rpc-url $RPC_URL --broadcast

    source .env && \
    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC FOUNDRY_PROFILE=oracles forge verify-contract 0x8A3C8F33b36B935f5E68108E664FB139B54eC0E8 \
    silo-oracles/contracts/pyth/PythAggregatorFactory.sol:PythAggregatorFactory \
    --constructor-args $(cast abi-encode "constructor(address)" 0x2880aB155794e7179c9eE2e38200202908C17B43) \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_URL \
    --watch
 */
contract PythAggregatorFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        address pyth = AddrLib.getAddress("PYTH");
        factory = address(new PythAggregatorFactory(pyth));

        vm.stopBroadcast();
    }
}
