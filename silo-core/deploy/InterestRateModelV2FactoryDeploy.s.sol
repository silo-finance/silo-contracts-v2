// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {
    IInterestRateModelV2Factory,
    InterestRateModelV2Factory
} from "silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/InterestRateModelV2FactoryDeploy.s.sol:InterestRateModelV2FactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
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
