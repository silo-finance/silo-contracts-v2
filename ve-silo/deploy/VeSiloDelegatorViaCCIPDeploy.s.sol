// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";
import {VeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/VeSiloDelegatorViaCCIP.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/VeSiloDelegatorViaCCIPDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VeSiloDelegatorViaCCIPDeploy is CommonDeploy {
    function run() public returns (IVeSiloDelegatorViaCCIP delegator) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address veSilo = getDeployedAddress(VeSiloContracts.VOTING_ESCROW);
        address remapper = getDeployedAddress(VeSiloContracts.VOTING_ESCROW_REMAPPER);

        delegator = IVeSiloDelegatorViaCCIP(address(
            new VeSiloDelegatorViaCCIP(
                IVeSilo(veSilo),
                IVotingEscrowCCIPRemapper(remapper),
                getAddress(VeSiloAddrKey.CHAINLINK_CCIP_ROUTER),
                getAddress(VeSiloAddrKey.LINK)
            )
        ));

        vm.stopBroadcast();

        _registerDeployment(address(delegator), VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP);
        _syncDeployments();
    }
}
