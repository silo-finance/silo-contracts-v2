// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {XSiloDeployments, XSiloContracts} from "x-silo/common/XSiloContracts.sol";
import {Stream} from "x-silo/contracts/modules/Stream.sol";
import {XSiloDeploy} from "x-silo/deploy/XSiloDeploy.s.sol";

/**
    FOUNDRY_PROFILE=x-silo \
        forge script x-silo/deploy/StreamDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract StreamDeploy is CommonDeploy {
    function run() public returns (Stream stream) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address dao = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);
        address xSilo = XSiloDeployments.get(XSiloContracts.X_SILO, ChainsLib.chainAlias());

        vm.startBroadcast(deployerPrivateKey);
        stream = new Stream(dao, xSilo);
        vm.stopBroadcast();

        _registerDeployment(address(stream), XSiloContracts.STREAM);
    }
}
