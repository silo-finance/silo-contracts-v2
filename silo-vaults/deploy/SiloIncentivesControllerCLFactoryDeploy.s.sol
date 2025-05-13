// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {
    SiloIncentivesControllerCLFactory
} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCLFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloIncentivesControllerCLFactoryDeploy.s.sol \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloIncentivesControllerCLFactoryDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
*/
contract SiloIncentivesControllerCLFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);
        factory = address(new SiloIncentivesControllerCLFactory());
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloVaultsContracts.SILO_INCENTIVES_CONTROLLER_CL_FACTORY);
    }
}
