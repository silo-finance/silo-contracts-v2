// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {IInterestRateModelV2, InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/InterestRateModelV2Deploy.s.sol:InterestRateModelV2Deploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify

    code verification:

    FOUNDRY_PROFILE=core forge verify-contract 0xc4Ea88E05262d2B5cf53aA78C65Fb7511e3C4C15 \
    silo-core/contracts/interestRateModel/InterestRateModelV2.sol:InterestRateModelV2 \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch
 */
contract InterestRateModelV2Deploy is CommonDeploy {
    function run() public returns (IInterestRateModelV2 interestRateModelV2) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        interestRateModelV2 = IInterestRateModelV2(address(new InterestRateModelV2()));

        vm.stopBroadcast();

        _registerDeployment(address(interestRateModelV2), SiloCoreContracts.INTEREST_RATE_MODEL_V2);
    }
}
