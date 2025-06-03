// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloDeployWithDeployerOwner} from "silo-core/deploy/silo/SiloDeployWithDeployerOwner.s.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";

import {
    SiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol";

import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";

import {
    SiloIncentivesControllerGLDeployments
} from "silo-core/deploy/incentives-controller/SiloIncentivesControllerGLDeployments.sol";

/**
FOUNDRY_PROFILE=core CONFIG=SILO_PendleLPT_wstkscETH-18DEC2025 INCENTIVES_OWNER=GROWTH_MULTISIG \
    forge script silo-core/deploy/silo/SiloPendleLPTDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloPendleLPTDeploy is SiloDeployWithDeployerOwner {
    function run() public override returns (ISiloConfig siloConfig) {
        string memory chainAlias = ChainsLib.chainAlias();

        siloConfig = super.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        string memory incentivesOwnerKey = vm.envString("INCENTIVES_OWNER");
        address incentivesOwner = AddrLib.getAddressSafe(chainAlias, incentivesOwnerKey);
        address dao = AddrLib.getAddressSafe(chainAlias, AddrKey.DAO);

        address factory = SiloCoreDeployments.get(
            SiloCoreContracts.INCENTIVES_CONTROLLER_GAUGE_LIKE_FACTORY,
            ChainsLib.chainAlias()
        );

        (address silo0, address silo1) = siloConfig.getSilos();
        (address protectedTokenSilo0,,) = siloConfig.getShareTokens(silo0);

        ISiloConfig.ConfigData memory config = ISiloConfig(siloConfig).getConfig(silo0);
        address hookReceiver = config.hookReceiver;

        vm.startBroadcast(deployerPrivateKey);

        address incentivesControllerLPTTokenSilo0 = SiloIncentivesControllerGaugeLikeFactory(factory).createGaugeLike({
            _owner: incentivesOwner,
            _notifier: hookReceiver,
            _shareToken: protectedTokenSilo0
        });

        address incentivesControllerSilo1 = SiloIncentivesControllerGaugeLikeFactory(factory).createGaugeLike({
            _owner: incentivesOwner,
            _notifier: hookReceiver,
            _shareToken: silo1 // collateral share token
        });

        Ownable(hookReceiver).transferOwnership(dao);

        vm.stopBroadcast();

        SiloIncentivesControllerGLDeployments.save(
            ChainsLib.chainAlias(),
            protectedTokenSilo0,
            incentivesControllerLPTTokenSilo0
        );

        SiloIncentivesControllerGLDeployments.save(
            ChainsLib.chainAlias(),
            silo1,
            incentivesControllerSilo1
        );

        console2.log("\n--------------------------------");
        console2.log("Incentives controller created for:");
        console2.log("silo", silo0);
        console2.log("hookReceiver", hookReceiver);
        console2.log("shareToken", protectedTokenSilo0);

        console2.log("\n--------------------------------");
        console2.log("Incentives controller created for:");
        console2.log("silo", silo1);
        console2.log("hookReceiver", hookReceiver);
        console2.log("shareToken", silo1);
    }
}
