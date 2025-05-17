// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {PublicAllocator} from "../contracts/PublicAllocator.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/PublicAllocatorDeploy.s.sol:PublicAllocatorDeploy \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/PublicAllocatorDeploy.s.sol:PublicAllocatorDeploy \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
*/
contract PublicAllocatorDeploy is CommonDeploy {
    function run() public returns (PublicAllocator publicAllocator) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);
        publicAllocator = new PublicAllocator();

        vm.stopBroadcast();

        _registerDeployment(address(publicAllocator), SiloVaultsContracts.PUBLIC_ALLOCATOR);
    }
}
