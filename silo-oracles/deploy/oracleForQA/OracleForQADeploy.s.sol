// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {OracleForQA} from "silo-oracles/contracts/oracleForQA/OracleForQA.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";

/*
ETHERSCAN_API_KEY=$ARBISCAN_API_KEY \
FOUNDRY_PROFILE=oracles \
BASE=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 \
QUOTE=0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
ADMIN=0x0000000000000000000000000000000000000000 \
    forge script silo-oracles/deploy/oracleForQA/OracleForQADeploy.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract OracleForQADeploy is CommonDeploy {
    function run() public returns (OracleForQA oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address base = vm.envAddress("BASE");
        address quote = vm.envAddress("QUOTE");
        address admin = vm.envAddress("ADMIN");
        string memory bSymbol = IERC20Metadata(base).symbol();
        string memory qSymbol = IERC20Metadata(quote).symbol();

        vm.startBroadcast(deployerPrivateKey);

        oracle = new OracleForQA(base, quote, admin);

        vm.stopBroadcast();

        string memory oracleName = string.concat("OracleForQA_", bSymbol, "-", qSymbol);

        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
    }
}
