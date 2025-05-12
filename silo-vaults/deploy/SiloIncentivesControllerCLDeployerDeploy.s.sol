// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts, SiloVaultsDeployments} from "silo-vaults/common/SiloVaultsContracts.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {
    SiloIncentivesControllerCLDeployer
} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCLDeployer.sol";

import {
    ISiloIncentivesControllerCLFactory
} from "silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloIncentivesControllerCLDeployerDeploy.s.sol \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloIncentivesControllerCLDeployerDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout \
        --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
*/
contract SiloIncentivesControllerCLDeployerDeploy is CommonDeploy {
    ISiloIncentivesControllerCLFactory siloIncentivesControllerCLFactory;

    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        if (address(siloIncentivesControllerCLFactory) == address(0)) {
            string memory chainAlias = ChainsLib.chainAlias();

            siloIncentivesControllerCLFactory = ISiloIncentivesControllerCLFactory(
                SiloVaultsDeployments.get(SiloVaultsContracts.SILO_INCENTIVES_CONTROLLER_CL_FACTORY, chainAlias)
            );
        }

        vm.startBroadcast(deployerPrivateKey);
        factory = address(new SiloIncentivesControllerCLDeployer(siloIncentivesControllerCLFactory));
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloVaultsContracts.SILO_INCENTIVES_CONTROLLER_CL_DEPLOYER);
    }

    function setCLFactory(ISiloIncentivesControllerCLFactory _siloIncentivesControllerCLFactory) external {
        siloIncentivesControllerCLFactory = _siloIncentivesControllerCLFactory;
    }
}
