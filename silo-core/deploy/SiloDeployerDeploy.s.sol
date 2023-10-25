// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";
import {IInterestRateModelV2ConfigFactory} from "silo-core/contracts/interfaces/IInterestRateModelV2ConfigFactory.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IHookReceiversFactory} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiversFactory.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";

import {console} from "forge-std/console.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloDeployerDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDeployerDeploy is CommonDeploy {
    function run() public returns (ISiloDeployer siloDeployer) {
        string memory chainAlias = getChainAlias();
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);
        address siloFactory = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, chainAlias);
        address hookReceiversFactory = SiloCoreDeployments.get(SiloCoreContracts.HOOK_RECEIVERS_FACTORY, chainAlias);
        
        address irmConfigFactory = SiloCoreDeployments.get(
            SiloCoreContracts.INTEREST_RATE_MODEL_V2_CONFIG_FACTORY,
            chainAlias
        );

        siloDeployer = ISiloDeployer(address(new SiloDeployer(
            IInterestRateModelV2ConfigFactory(irmConfigFactory),
            ISiloFactory(siloFactory),
            IHookReceiversFactory(hookReceiversFactory),
            timelock
        )));

        vm.stopBroadcast();

        _registerDeployment(address(siloDeployer), SiloCoreContracts.SILO_DEPLOYER);
    }
}
