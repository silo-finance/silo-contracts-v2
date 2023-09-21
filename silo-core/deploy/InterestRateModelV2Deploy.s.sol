// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";

import {IInterestRateModelV2, InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/InterestRateModelV2Deploy.s.sol:InterestRateModelV2Deploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract InterestRateModelV2Deploy is CommonDeploy {
    function run() public returns (IInterestRateModelV2 interestRateModelV2) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        interestRateModelV2 = IInterestRateModelV2(address(new InterestRateModelV2()));

        vm.stopBroadcast();

        _registerDeployment(address(interestRateModelV2), SiloCoreContracts.INTEREST_RATE_MODEL_V2);
        _syncDeployments();
    }
}
