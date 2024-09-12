// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloDeployerDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDeployerDeploy is CommonDeploy {
    function run() public returns (ISiloDeployer siloDeployer) {
        string memory chainAlias = getChainAlias();
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        ISiloFactory siloFactory = ISiloFactory(SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, chainAlias));

        address irmConfigFactory = SiloCoreDeployments.get(
            SiloCoreContracts.INTEREST_RATE_MODEL_V2_FACTORY,
            chainAlias
        );

        vm.startBroadcast(deployerPrivateKey);

        address siloImpl = address(new Silo(siloFactory));
        address shareProtectedCollateralTokenImpl = address(new ShareProtectedCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        siloDeployer = ISiloDeployer(address(new SiloDeployer(
            IInterestRateModelV2Factory(irmConfigFactory),
            siloFactory,
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl
        )));

        vm.stopBroadcast();

        _registerDeployment(address(siloDeployer), SiloCoreContracts.SILO_DEPLOYER);
        _registerDeployment(address(siloImpl), SiloCoreContracts.SILO);
        _registerDeployment(address(shareProtectedCollateralTokenImpl), SiloCoreContracts.SHARE_PORTECTED_COLLATERAL_TOKEN);
        _registerDeployment(address(shareDebtTokenImpl), SiloCoreContracts.SHARE_DEBT_TOKEN);
    }
}
