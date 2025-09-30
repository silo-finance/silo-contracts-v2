// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloIncentivesControllerGaugeLikeFactory} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol";
import {ISiloIncentivesControllerGaugeLikeFactory} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloIncentivesControllerGaugeLikeFactoryDeploy.s.sol \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloIncentivesControllerGaugeLikeFactoryDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract SiloIncentivesControllerGaugeLikeFactoryDeploy is CommonDeploy {
    function run() public returns (ISiloIncentivesControllerGaugeLikeFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = ISiloIncentivesControllerGaugeLikeFactory(address(new SiloIncentivesControllerGaugeLikeFactory()));

        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloCoreContracts.INCENTIVES_CONTROLLER_GAUGE_LIKE_FACTORY);
    }
}
