// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {sAVAXOracle} from "../../contracts/custom/sAVAX/sAVAXOracle.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/custom/sAVAXOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/custom/sAVAXOracleDeploy.s.sol \
        --ffi --rpc-url $RPC_AVALANCHE \
        --verify \
        --private-key $PRIVATE_KEY \
        --resume
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
        address vault = address(sAVAXOracle(address(oracle)).S_AVAX());
        address baseToken = sAVAXOracle(address(oracle)).IAU_SAVAX();

        console2.log(
            "fetch price for: %s/%s\n", IERC20Metadata(vault).symbol(), IERC20Metadata(oracle.quoteToken()).symbol()
        );
        printQuote(oracle, baseToken, uint256(10 ** IERC20Metadata(baseToken).decimals()));
    }
}
