// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {IFIRMHook} from "silo-core/contracts/interfaces/IFIRMHook.sol";
import {FIRMHook} from "silo-core/contracts/hooks/firm/FIRMHook.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/FIRMHookDeploy.s.sol \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/FIRMHookDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract FIRMHookDeploy is CommonDeploy {
    function run() public returns (IFIRMHook hookReceiver) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        hookReceiver = IFIRMHook(address(new FIRMHook()));

        vm.stopBroadcast();

        _registerDeployment(address(hookReceiver), SiloCoreContracts.FIRM_HOOK);
    }
}
