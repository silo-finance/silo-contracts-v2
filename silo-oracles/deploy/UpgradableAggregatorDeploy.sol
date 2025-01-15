// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {UpgradableAggregator} from "silo-oracles/contracts/upgradableAggregator/UpgradableAggregator.sol";

/**
    OWNER=0x7461d8c0fDF376c847b651D882DEa4C73fad2e4B UNDERLYING_FEED=0xaeaB676fEfeFE1ebB85E56E5204Efd9A8bB5E6C7 \
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/UpgradableAggregatorDeploy.sol \
        --ffi --rpc-url $RPC_URL --broadcast

    # contract source must be in foundry project src folder
    source .env && \
    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC FOUNDRY_PROFILE=oracles forge verify-contract 0x8A3C8F33b36B935f5E68108E664FB139B54eC0E8 \
    silo-oracles/contracts/upgradableAggregator/UpgradableAggregator.sol:UpgradableAggregator \
    --constructor-args $(cast abi-encode "constructor(address,address)" 0x7461d8c0fDF376c847b651D882DEa4C73fad2e4B 0x70073098984050f5563333Be76BCd94D21d8673A) \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_URL \
    --watch
 */
contract UpgradableAggregatorDeploy is CommonDeploy {
    function run() public returns (address aggregator) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("OWNER");
        AggregatorV3Interface underlyingFeed = AggregatorV3Interface(vm.envAddress("UNDERLYING_FEED"));

        aggregator = address(new UpgradableAggregator(owner, underlyingFeed));

        vm.stopBroadcast();
    }
}
