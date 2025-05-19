// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {XSiloDeployments, XSiloContracts} from "x-silo/common/XSiloContracts.sol";
import {StreamDeploy} from "x-silo/deploy/StreamDeploy.s.sol";
import {XSilo} from "x-silo/contracts/XSilo.sol";

/**
    FOUNDRY_PROFILE=x_silo \
        forge script x-silo/deploy/XSiloDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    verify code in case of issues:

    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC FOUNDRY_PROFILE=x_silo \
        forge script x-silo/deploy/XSiloDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --resume --verify \
        --verifier-url https://api.sonicscan.org/api \
        --private-key $PRIVATE_KEY

 */
contract XSiloDeploy is CommonDeploy {
    function run() public returns (XSilo xSilo) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        string memory chainAlias = ChainsLib.chainAlias();

        address siloTokenV2 = XSiloDeployments.get(AddrKey.SILO_TOKEN_V2, chainAlias);
        address dao = AddrLib.getAddressSafe(chainAlias, AddrKey.DAO);
        address stream = XSiloDeployments.get(XSiloContracts.STREAM, chainAlias);

        vm.startBroadcast(deployerPrivateKey);
        xSilo = new XSilo(dao, siloTokenV2, stream);
        vm.stopBroadcast();

        _registerDeployment(address(xSilo), XSiloContracts.X_SILO);
    }
}
