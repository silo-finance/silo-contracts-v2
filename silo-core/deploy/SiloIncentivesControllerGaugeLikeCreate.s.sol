// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloIncentivesControllerGaugeLikeFactory} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol";
import {ISiloIncentivesControllerGaugeLikeFactory} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/**
    OWNER=0x4d62b6E166767988106cF7Ee8fE23E480E76FF1d \
    NOTIFIER=0xB01e62Ba9BEc9Cfa24b2Ee321392b8Ce726D2A09 \
    SHARE_TOKEN=0x4E216C15697C1392fE59e1014B009505E05810Df \
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloIncentivesControllerGaugeLikeCreate.s.sol \
        --ffi --broadcast --rpc-url $RPC_SONIC --verify
 */
contract SiloIncentivesControllerGaugeLikeCreate is CommonDeploy {
    function run() public returns (address incentivesControllerGaugeLike) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address owner = vm.envAddress("OWNER");
        address notifier = vm.envAddress("NOTIFIER");
        address shareToken = vm.envAddress("SHARE_TOKEN");

        address factory = SiloCoreDeployments.get(
            SiloCoreContracts.INCENTIVES_CONTROLLER_GAUGE_LIKE_FACTORY,
            ChainsLib.chainAlias()
        );

        vm.startBroadcast(deployerPrivateKey);

        incentivesControllerGaugeLike = SiloIncentivesControllerGaugeLikeFactory(factory).createGaugeLike(
            owner,
            notifier,
            shareToken
        );

        vm.stopBroadcast();
    }
}
