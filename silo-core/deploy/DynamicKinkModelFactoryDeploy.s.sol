// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {DynamicKinkModelFactory, IInterestRateModelFactory} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/DynamicKinkModelFactoryDeploy.s.sol:DynamicKinkModelFactoryDeploy \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/DynamicKinkModelFactoryDeploy.s.sol:DynamicKinkModelFactoryDeploy \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract DynamicKinkModelFactoryDeploy is CommonDeploy {
    function run() public returns (IInterestRateModelFactory irmFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        irmFactory = IInterestRateModelFactory(address(new DynamicKinkModelFactory()));

        vm.stopBroadcast();

        _registerDeployment(address(irmFactory), SiloCoreContracts.DYNAMIC_KINK_MODEL_FACTORY);
    }
}
