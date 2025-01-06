// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/VaultIncentivesModuleDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify
*/
contract VaultIncentivesModuleDeploy is CommonDeploy {
    function run() public returns (VaultIncentivesModule incentivesModule) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address owner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        incentivesModule = new VaultIncentivesModule(owner);
        vm.stopBroadcast();

        _registerDeployment(address(incentivesModule), SiloVaultsContracts.VAULT_INCENTIVES_MODULE);
    }
}
