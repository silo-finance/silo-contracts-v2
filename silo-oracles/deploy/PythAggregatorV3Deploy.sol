// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {PythAggregatorV3} from "pyth-sdk-solidity/PythAggregatorV3.sol";
import {CommonDeploy} from "./CommonDeploy.sol";

/**
    PYTH=0x2880aB155794e7179c9eE2e38200202908C17B43 PYTH_FEED_ID=0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace \
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/PythAggregatorV3Deploy.sol \
        --ffi --rpc-url $RPC_URL --broadcast

    # contract source must be in foundry project src folder
    mkdir silo-oracles/contracts/pyth && \
    cp gitmodules/pyth-sdk-solidity/target_chains/ethereum/sdk/solidity/* silo-oracles/contracts/tmp && \
    source .env && \
    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC FOUNDRY_PROFILE=oracles forge verify-contract 0x70073098984050f5563333Be76BCd94D21d8673A \
    silo-oracles/contracts/tmp/PythAggregatorV3.sol:PythAggregatorV3 \
    --constructor-args $(cast abi-encode "constructor(address,bytes32)" 0x2880aB155794e7179c9eE2e38200202908C17B43 0xf490b178d0c85683b7a0f2388b40af2e6f7c90cbe0f96b31f315f08d0e5a2d6d) \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_URL \
    --watch
 */
contract PythAggregatorV3Deploy is CommonDeploy {
    function run() public returns (address aggregator) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        address pyth = vm.envAddress("PYTH");
        bytes32 priceFeedId = vm.envBytes32("PYTH_FEED_ID");

        aggregator = address(new PythAggregatorV3(pyth, priceFeedId));

        vm.stopBroadcast();
    }
}
