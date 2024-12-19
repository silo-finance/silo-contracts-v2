// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloIncentivesControllerGaugeLikeFactory} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol";
import {ISiloIncentivesControllerGaugeLikeFactory} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloIncentivesControllerGaugeLikeFactoryDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify
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
