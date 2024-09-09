// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {TransparentUpgradeableProxy} from "openzeppelin5/proxy/transparent/TransparentUpgradeableProxy.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";
import {VeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/VeSiloDelegatorViaCCIP.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/VeSiloDelegatorViaCCIPDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VeSiloDelegatorViaCCIPDeploy is CommonDeploy {
    function run() public returns (IVeSiloDelegatorViaCCIP delegator) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address veSilo = getDeployedAddress(VeSiloContracts.VOTING_ESCROW);
        address remapper = getDeployedAddress(VeSiloContracts.VOTING_ESCROW_REMAPPER);
        address chainlinkCCIPRouter = getAddress(AddrKey.CHAINLINK_CCIP_ROUTER);
        address link = getAddress(AddrKey.LINK);
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());

        bytes memory data = abi.encodeWithSelector(
            VeSiloDelegatorViaCCIP.initialize.selector,
            timelock
        );

        vm.startBroadcast(deployerPrivateKey);

        address implementation = address(
            new VeSiloDelegatorViaCCIP(
                IVeSilo(veSilo),
                IVotingEscrowCCIPRemapper(remapper),
                chainlinkCCIPRouter,
                link
            )
        );

        delegator = IVeSiloDelegatorViaCCIP(address(new TransparentUpgradeableProxy(implementation, timelock, data)));

        vm.stopBroadcast();

        _registerDeployment(address(delegator), VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP);
    }
}
