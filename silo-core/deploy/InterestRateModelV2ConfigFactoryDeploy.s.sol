// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";

import {
    IInterestRateModelV2ConfigFactory,
    InterestRateModelV2ConfigFactory
} from "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/InterestRateModelV2ConfigFactoryDeploy.s.sol:InterestRateModelV2ConfigFactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract InterestRateModelV2ConfigFactoryDeploy is CommonDeploy {
    function run() public returns (IInterestRateModelV2ConfigFactory interestRateModelV2ConfigFactory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        interestRateModelV2ConfigFactory =
            IInterestRateModelV2ConfigFactory(address(new InterestRateModelV2ConfigFactory()));

        vm.stopBroadcast();

        _registerDeployment(
            address(interestRateModelV2ConfigFactory), SiloCoreContracts.INTEREST_RATE_MODEL_V2_CONFIG_FACTORY
        );
        _syncDeployments();
    }
}
