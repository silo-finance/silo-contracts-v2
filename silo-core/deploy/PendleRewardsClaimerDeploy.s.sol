// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {PendleRewardsClaimer} from "silo-core/contracts/hooks/PendleRewardsClaimer.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/PendleRewardsClaimerDeploy.s.sol \
        --ffi --rpc-url $RPC_MAINNET --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/PendleRewardsClaimerDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract PendleRewardsClaimerDeploy is CommonDeploy {
    function run() public returns (PendleRewardsClaimer hookReceiver) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        hookReceiver = new PendleRewardsClaimer();

        vm.stopBroadcast();

        _registerDeployment(address(hookReceiver), SiloCoreContracts.PENDLE_REWARDS_CLAIMER);
    }
}
