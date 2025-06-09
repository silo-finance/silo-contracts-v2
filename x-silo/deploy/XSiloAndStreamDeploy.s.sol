// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {XSiloDeploy} from "x-silo/deploy/XSiloDeploy.s.sol";
import {StreamDeploy} from "x-silo/deploy/StreamDeploy.s.sol";
import {XSilo} from "x-silo/contracts/XSilo.sol";
import {Stream} from "x-silo/contracts/modules/Stream.sol";
import {XSiloContracts} from "x-silo/common/XSiloContracts.sol";
import {CommonDeploy} from "x-silo/deploy/CommonDeploy.sol";
import {ComputeAddrLib} from "common/utils/ComputeAddrLib.sol";

/**
    FOUNDRY_PROFILE=x_silo \
        forge script x-silo/deploy/XSiloAndStreamDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    verify code in case of issues:

    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC FOUNDRY_PROFILE=x_silo \
        forge script x-silo/deploy/XSiloAndStreamDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --resume --verify \
        --private-key $PRIVATE_KEY
 */
contract XSiloAndStreamDeploy is CommonDeploy {
    function run() public returns (XSilo xSilo, Stream stream) {
        address deployer = vm.addr(uint256(vm.envBytes32("PRIVATE_KEY")));
        uint256 nonce = vm.getNonce(deployer);

        // Calculate contract addresses that will be created
        xSilo = XSilo(ComputeAddrLib.computeAddress(deployer, nonce));      // First deployment
        stream = Stream(ComputeAddrLib.computeAddress(deployer, nonce + 1));  // Second deployment

        // Set the addresses
        AddrLib.setAddress(XSiloContracts.STREAM, address(stream));
        AddrLib.setAddress(XSiloContracts.X_SILO, address(xSilo));
        
        // Create deploy instances and run them
        StreamDeploy streamDeploy = new StreamDeploy();
        XSiloDeploy xSiloDeploy = new XSiloDeploy();
        
        xSiloDeploy.run();
        streamDeploy.run();
    }
}
