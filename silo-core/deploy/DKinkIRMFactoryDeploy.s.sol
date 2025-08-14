// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {CommonDeploy} from "./_CommonDeploy.sol";

import {IDynamicKinkModelFactory} from "silo-core/contracts/interfaces/IDynamicKinkModelFactory.sol";
import {DynamicKinkModelFactory} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

/*
FOUNDRY_PROFILE=core forge script silo-core/deploy/DKinkIRMFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract DKinkIRMFactoryDeploy is CommonDeploy {
    function run() public virtual returns (IDynamicKinkModelFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = IDynamicKinkModelFactory(address(new DynamicKinkModelFactory()));

        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloCoreContracts.DYNAMIC_KINK_MODEL_FACTORY);
    }
}
