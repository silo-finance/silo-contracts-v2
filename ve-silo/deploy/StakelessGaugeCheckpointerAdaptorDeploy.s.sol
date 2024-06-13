// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {StakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/stakeless-gauge/StakelessGaugeCheckpointerAdaptor.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/StakelessGaugeCheckpointerAdaptorDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract StakelessGaugeCheckpointerAdaptorDeploy is CommonDeploy {
    function run() public returns (IStakelessGaugeCheckpointerAdaptor adaptor) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());

        vm.startBroadcast(deployerPrivateKey);

        adaptor = IStakelessGaugeCheckpointerAdaptor(address(
            new StakelessGaugeCheckpointerAdaptor(getAddress(AddrKey.LINK))
        ));

        Ownable(address(adaptor)).transferOwnership(timelock);
        
        vm.stopBroadcast();

        _registerDeployment(address(adaptor), VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);
    }
}
