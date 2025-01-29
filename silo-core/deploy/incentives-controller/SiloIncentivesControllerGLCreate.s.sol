// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";

import {
    SiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol";

import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloIncentivesControllerGLDeployments} from "./SiloIncentivesControllerGLDeployments.sol";

/**
    INCENTIVES_OWNER=DAO SILO=wS_scUSD_Silo INCENTIVIZED_ASSET=scUSD \
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/incentives-controller/SiloIncentivesControllerGLCreate.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloIncentivesControllerGLCreate is CommonDeploy {
    error OwnerNotFound();
    error SiloNotFound();
    error IncentivizedAssetNotFound();
    error IncentivizedAssetMismatch();

    address public incentivesOwner;
    address public incentivizedAsset;
    address public siloConfig;
    address public hookReceiver;

    function setIncentivesOwner(address _incentivesOwner) public {
        incentivesOwner = _incentivesOwner;
    }

    function setIncentivizedAsset(address _incentivizedAsset) public {
        incentivizedAsset = _incentivizedAsset;
    }

    function setSiloConfig(address _siloConfig) public {
        siloConfig = _siloConfig;
    }

    function run() public returns (address incentivesControllerGaugeLike) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        if (incentivesOwner == address(0)) {
            string memory incentivesOwnerKey = vm.envString("INCENTIVES_OWNER");
            incentivesOwner = AddrLib.getAddress(incentivesOwnerKey);
            require(incentivesOwner != address(0), OwnerNotFound());
        }

        if (incentivizedAsset == address(0)) {
            string memory incentivizedAssetKey = vm.envString("INCENTIVIZED_ASSET");
            incentivizedAsset = AddrLib.getAddress(incentivizedAssetKey);
            require(incentivizedAsset != address(0), IncentivizedAssetNotFound());
        }

        if (siloConfig == address(0)) {
            string memory siloKey = vm.envString("SILO");
            siloConfig = SiloDeployments.get(ChainsLib.chainAlias(), siloKey);
            require(siloConfig != address(0), SiloNotFound());
        }

        address factory = SiloCoreDeployments.get(
            SiloCoreContracts.INCENTIVES_CONTROLLER_GAUGE_LIKE_FACTORY,
            ChainsLib.chainAlias()
        );

        (address incentivizedSilo, address silo1) = ISiloConfig(siloConfig).getSilos();

        ISiloConfig.ConfigData memory config = ISiloConfig(siloConfig).getConfig(incentivizedSilo);

        if (config.token != incentivizedAsset) {
            incentivizedSilo = silo1;
            config = ISiloConfig(siloConfig).getConfig(incentivizedSilo);

            require(config.token == incentivizedAsset, IncentivizedAssetMismatch());
        }

        hookReceiver = config.hookReceiver;
        incentivizedAsset = incentivizedSilo; // collateral share token

        console2.log("\n--------------------------------");
        console2.log("Incentives controller created for:");
        console2.log("silo", incentivizedSilo);
        console2.log("hookReceiver", hookReceiver);
        console2.log("shareToken", incentivizedSilo);

        vm.startBroadcast(deployerPrivateKey);

        incentivesControllerGaugeLike = SiloIncentivesControllerGaugeLikeFactory(factory).createGaugeLike({
            _owner: incentivesOwner,
            _notifier: hookReceiver,
            _shareToken: incentivizedSilo
        });

        vm.stopBroadcast();

        SiloIncentivesControllerGLDeployments.save(ChainsLib.chainAlias(), incentivizedSilo, incentivesControllerGaugeLike);
    }
}
