// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {console2} from "forge-std/console2.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {WrappedVaultOraclesConfigsParser} from "./WrappedVaultOracleConfigsParser.sol";
import {WrappedVaultOracle} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracle.sol";
import {IWrappedVaultOracle} from "silo-oracles/contracts/interfaces/IWrappedVaultOracle.sol";
import {WrappedVaultOracleFactory} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracleFactory.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {WrappedVaultOracleConfig} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracleConfig.sol";

/**
FOUNDRY_PROFILE=oracles CONFIG=CHAINLINK_scUSD_USDC_USD \
    forge script silo-oracles/deploy/wrappedVault/WrappedVaultOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract WrappedVaultOracleDeploy is CommonDeploy {
    string public useConfigName;

    function setUseConfigName(string memory _useConfigName) public {
        useConfigName = _useConfigName;
    }
    
    function run() public returns (WrappedVaultOracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory configName = bytes(useConfigName).length != 0 ? useConfigName : vm.envString("CONFIG");

        IWrappedVaultOracle.WrappedVaultDeploymentConfig memory deployCfg = WrappedVaultOraclesConfigsParser.getConfig(
            getChainAlias(),
            configName
        );

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.WRAPPED_VAULT_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = WrappedVaultOracleFactory(factory).create(deployCfg, bytes32(0));

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), configName, address(oracle));

        console2.log("Config name", configName);

        IWrappedVaultOracle.Config memory cfg = oracle.oracleConfig().getConfig();

        address baseToken = address(cfg.baseToken);
        _printMetadata(baseToken);

        printQuote(oracle, baseToken, 1);
        printQuote(oracle, baseToken, 10);
        printQuote(oracle, baseToken, 1e6);
        printQuote(oracle, baseToken, 1e8);
        printQuote(oracle, baseToken, 1e18);
        printQuote(oracle, baseToken, 1e36);

        console2.log("Using token decimals:");
        uint256 price = printQuote(oracle, baseToken, uint256(10 ** cfg.baseToken.decimals()));
        console2.log("Price in quote token divided by 1e18: ", _formatNumberInE(price / 1e18));

        console2.log("Oracle config:");
        console2.log("baseToken: ", address(cfg.baseToken));
        console2.log("quoteToken: ", address(cfg.quoteToken));
        console2.log("vaultAsset: ", address(cfg.vaultAsset));
        console2.log("oracle: ", address(cfg.oracle));
    }
}
