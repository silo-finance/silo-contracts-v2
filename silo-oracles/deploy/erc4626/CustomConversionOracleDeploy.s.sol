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
FOUNDRY_PROFILE=oracles VAULT=sAVAX METHOD=getPooledAvaxByShares QUOTE_TOKEN=wAVAX \
    forge script silo-oracles/deploy/erc4626/CustomConversionOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract CustomConversionOracleDeploy is CommonDeploy {
    string public vaultKey;

    function setVaultKey(string memory _vaultKey) public {
        vaultKey = _vaultKey;
    }

    function run() public returns (ISiloOracle oracle) {
        AddrLib.init();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        if (bytes(vaultKey).length == 0) {
            vaultKey = vm.envString("VAULT");
        }

        address vault = AddrLib.getAddress(vaultKey);
        string memory method = vm.envString("METHOD");
        address quoteToken = AddrLib.getAddress(vm.envString("QUOTE_TOKEN"));

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.CUSTOM_CONVERSION_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = CustomConversionOracleFactory(factory).create(vault, method, quoteToken, bytes32(0));

        vm.stopBroadcast();

        string memory oracleName = string.concat("CUSTOM_CONVERSION_", vaultKey);

        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));

        _qa(oracle, vault);
    }

    function _qa(ISiloOracle oracle, address vault) internal view {
        console2.log("fetch price for: %s", IERC20Metadata(vault).symbol());
        printQuote(oracle, address(vault), uint256(10 ** IERC20Metadata(vault).decimals()));
    }
}
