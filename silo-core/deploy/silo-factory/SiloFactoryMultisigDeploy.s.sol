// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloFactoryDeploy} from "./SiloFactoryDeploy.s.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/silo-factory/SiloFactoryMultisigDeploy.s.sol:SiloFactoryMultisigDeploy \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/silo-factory/SiloFactoryMultisigDeploy.s.sol:SiloFactoryMultisigDeploy \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout \
        --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract SiloFactoryMultisigDeploy is SiloFactoryDeploy {
    function _getOwner() internal override returns (address owner) {
        owner = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);
    }

    function _getFeeReceiver() internal override returns (address feeReceiver) {
        feeReceiver = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);
    }
}
