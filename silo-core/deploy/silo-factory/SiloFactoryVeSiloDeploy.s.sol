// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {SiloFactoryDeploy} from "./SiloFactoryDeploy.s.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/silo-factory/SiloFactoryVeSiloDeploy.s.sol:SiloFactoryVeSiloDeploy \
        --ffi --rpc-url http://127.0.0.1:8545 --verify --broadcast
 */
contract SiloFactoryVeSiloDeploy is SiloFactoryDeploy {
    function _getOwner() internal override returns (address owner) {
        owner = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, ChainsLib.chainAlias());
    }

    function _getFeeReceiver() internal override returns (address feeReceiver) {
        feeReceiver = VeSiloDeployments.get(VeSiloContracts.FEE_DISTRIBUTOR, ChainsLib.chainAlias());
    }
}
