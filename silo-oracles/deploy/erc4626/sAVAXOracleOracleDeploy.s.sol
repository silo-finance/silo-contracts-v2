// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ERC4626OracleFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";


/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/erc4626/sAVAXOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract sAVAXOracleDeploy is CommonDeploy {
    function run() public returns (ISiloOracle oracle) {
        AddrLib.init();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        oracle = new sAVAXOracle();

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), string.concat("sAVAX_wAVAX_ORACLE"), address(oracle));

        _qa(oracle);
    }

    function _qa(ISiloOracle oracle) internal view {
        console2.log("fetch price for: %s/%s", IERC20Metadata(sAVAXOracle(vault).S_AVAX()).symbol(), IERC20Metadata(oracle.quoteToken()).symbol());
        printQuote(oracle, address(vault), uint256(10 ** IERC20Metadata(vault).decimals()));
    }
}
