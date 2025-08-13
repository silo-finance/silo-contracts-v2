// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {IRMZero} from "silo-core/contracts/interestRateModel/IRMZero.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/IRMZeroDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/IRMZeroDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
*/
contract IRMZeroDeploy is CommonDeploy {
    function run() public returns (IRMZero irm) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        irm = new IRMZero();

        vm.stopBroadcast();

        _registerDeployment(address(irm), SiloCoreContracts.IRM_ZERO);
    }
}
