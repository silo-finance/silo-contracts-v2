// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {
    IInterestRateModelV2Factory,
    InterestRateModelV2Factory
} from "silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol";

/**
    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/InterestRateModelV2FactoryDeploy.s.sol:InterestRateModelV2FactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify

    FOUNDRY_PROFILE=core forge verify-contract 0xDA91d956498d667f5DB71eEcd58Ba02C4B960a53 \
    silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol:InterestRateModelV2Factory \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch
 */
contract InterestRateModelV2FactoryDeploy is CommonDeploy {
    function run() public returns (IInterestRateModelV2Factory interestRateModelV2ConfigFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        interestRateModelV2ConfigFactory =
            IInterestRateModelV2Factory(address(new InterestRateModelV2Factory()));

        vm.stopBroadcast();

        _registerDeployment(
            address(interestRateModelV2ConfigFactory), SiloCoreContracts.INTEREST_RATE_MODEL_V2_FACTORY
        );
    }
}
