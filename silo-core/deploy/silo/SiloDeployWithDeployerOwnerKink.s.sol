// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {SiloDeployKink, ISiloDeployer} from "./SiloDeployKink.s.sol";

/**
FOUNDRY_PROFILE=core CONFIG=solvBTC.BBN_solvBTC \
    forge script silo-core/deploy/silo/SiloDeployWithDeployerOwnerKink.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloDeployWithDeployerOwnerKink is SiloDeployKink {
    function _getClonableHookReceiverConfig(address _implementation)
        internal
        view
        override
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver)
    {
        hookReceiver = ISiloDeployer.ClonableHookReceiver({
            implementation: _implementation,
            initializationData: abi.encode(_getOwner())
        });
    }

    function _transferIRMOwnership(ISiloConfig _siloConfig) internal override {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address owner = vm.addr(deployerPrivateKey);

        (address silo0, address silo1) = _siloConfig.getSilos();
        _transferIRMOwnershipForSilo(_siloConfig, silo0);
        _transferIRMOwnershipForSilo(_siloConfig, silo1);
    }

    function _transferIRMOwnershipForSilo(ISiloConfig _siloConfig, address _silo) internal {
        address owner = _getOwner();

        ISiloConfig.ConfigData memory cfg = _siloConfig.getConfig(_silo);

        vm.startBroadcast();

        Ownable1and2Steps(cfg.interestRateModel).transferOwnership1Step(owner);

        vm.stopBroadcast();
    }

    function _getOwner() private view returns (address owner) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        owner = vm.addr(deployerPrivateKey);
    }
}
