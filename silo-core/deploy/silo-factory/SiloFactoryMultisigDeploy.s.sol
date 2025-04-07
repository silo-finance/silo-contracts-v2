// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloFactoryDeploy} from "./SiloFactoryDeploy.s.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/silo-factory/SiloFactoryMultisigDeploy.s.sol:SiloFactoryMultisigDeploy \
        --ffi --rpc-url http://127.0.0.1:8545 --verify --broadcast
 */
contract SiloFactoryMultisigDeploy is SiloFactoryDeploy {
    function _getOwner() internal override returns (address owner) {
        owner = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);
    }

    function _getFeeReceiver() internal override returns (address feeReceiver) {
        feeReceiver = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);
    }
}
