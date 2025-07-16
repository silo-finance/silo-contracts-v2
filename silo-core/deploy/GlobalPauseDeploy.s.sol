// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {GlobalPause} from "common/utils/GlobalPause.sol";
import {IGlobalPause} from "common/utils/interfaces/IGlobalPause.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/GlobalPauseDeploy.s.sol \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/GlobalPauseDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
*/
contract GlobalPauseDeploy is CommonDeploy {
    function run() public returns (IGlobalPause globalPause) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address dao = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);

        vm.startBroadcast(deployerPrivateKey);

        globalPause = new GlobalPause(dao);

        vm.stopBroadcast();

        _registerDeployment(address(globalPause), SiloCoreContracts.GLOBAL_PAUSE);
    }
}
