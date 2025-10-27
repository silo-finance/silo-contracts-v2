// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {RescueWAVAX} from "../../contracts/utils/RescueWAVAX.sol";

import {CommonDeploy} from "../common/CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/utils/RescueWAVAXDeploy.s.sol:RescueWAVAXDeploy \
        --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/utils/RescueWAVAXDeploy.s.sol:RescueWAVAXDeploy \
        --ffi --rpc-url $RPC_AVALANCHE \
        --verify \
        --verifier blockscout --verifier-url $ETHERSCAN_API_KEY \
        --private-key $PRIVATE_KEY \
        --resume
*/
contract RescueWAVAXDeploy is CommonDeploy {
    function run() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);
        RescueWAVAX newLogic = new RescueWAVAX();

        vm.stopBroadcast();

        _registerDeployment(address(newLogic), "RescueWAVAX.sol");
    }
}
