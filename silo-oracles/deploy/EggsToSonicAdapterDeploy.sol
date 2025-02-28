// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {EggsToSonicAdapter, IEggsLike} from "silo-oracles/contracts/custom/EggsToSonicAdapter.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/EggsToSonicAdapterDeploy.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract EggsToSonicAdapterDeploy is CommonDeploy {
    function run() public returns (EggsToSonicAdapter adapter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        IEggsLike eggs = IEggsLike(getAddress(AddrKey.EGGS));

        vm.startBroadcast(deployerPrivateKey);

        adapter = new EggsToSonicAdapter(eggs);

        vm.stopBroadcast();

        _registerDeployment(address(adapter), SiloOraclesContracts.EGGS_TO_SONIC_ADAPTER);
    }
}
