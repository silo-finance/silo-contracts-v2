// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ChainlinkV3OraclesConfigsParser as ConfigParser} from "./ChainlinkV3OraclesConfigsParser.sol";
import {ChainlinkV3Oracle} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3Oracle.sol";
import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";
import {ChainlinkV3OracleFactory} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {ChainlinkV3OracleConfig} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleConfig.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";

/**
FOUNDRY_PROFILE=oracles CONFIG=CHAINLINK_scUSD_USDC_USD \
    forge script silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract ChainlinkV3OracleDeploy is CommonDeploy {
    string public useConfigName;

    function setUseConfigName(string memory _useConfigName) public {
        useConfigName = _useConfigName;
    }
    
    function run() public returns (ChainlinkV3Oracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory configName = bytes(useConfigName).length != 0 ? useConfigName : vm.envString("CONFIG");

        IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config = ConfigParser.getConfig(
            getChainAlias(),
            configName
        );

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.CHAINLINK_V3_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = ChainlinkV3OracleFactory(factory).create(config, bytes32(0));

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), configName, address(oracle));

        console2.log("Config name", configName);

        console2.log("Token name:", config.baseToken.name());
        console2.log("Token symbol:", config.baseToken.symbol());
        console2.log("Token decimals:", config.baseToken.decimals());

        printQuote(oracle, config, 1);
        printQuote(oracle, config, 10);
        printQuote(oracle, config, 1e6);
        printQuote(oracle, config, 1e8);
        printQuote(oracle, config, 1e18);
        printQuote(oracle, config, 1e36);

        console2.log("Using token decimals:");
        uint256 price = printQuote(oracle, config, uint256(10 ** config.baseToken.decimals()));
        console2.log("Price in quote token divided by 1e18: ", PriceFormatter.formatPriceInE18(price / 1e18));

        ChainlinkV3OracleConfig oracleConfig = oracle.oracleConfig();
        IChainlinkV3Oracle.ChainlinkV3Config memory oracleConfigLive = oracleConfig.getConfig();
        console2.log("Oracle config:");
        console2.log("Primary aggregator: ", address(oracleConfigLive.primaryAggregator));
        console2.log("Secondary aggregator: ", address(oracleConfigLive.secondaryAggregator));
        console2.log("Primary heartbeat: ", oracleConfigLive.primaryHeartbeat);
        console2.log("Secondary heartbeat: ", oracleConfigLive.secondaryHeartbeat);
        console2.log("Normalization divider: ", PriceFormatter.formatNumberInE(oracleConfigLive.normalizationDivider));
        console2.log("Normalization multiplier: ", PriceFormatter.formatNumberInE(oracleConfigLive.normalizationMultiplier));
        console2.log("Base token: ", address(oracleConfigLive.baseToken));
        console2.log("Quote token: ", address(oracleConfigLive.quoteToken));
        console2.log("Convert to quote: ", oracleConfigLive.convertToQuote);
    }

    function printQuote(
        ChainlinkV3Oracle _oracle,
        IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory _config,
        uint256 _baseAmount
    ) internal view returns (uint256 quote) {
         try _oracle.quote(_baseAmount, address(_config.baseToken)) returns (uint256 price) {
            require(price > 0, string.concat("Quote for ", PriceFormatter.formatNumberInE(_baseAmount), " wei is 0"));
            console2.log(string.concat("Quote for ", PriceFormatter.formatNumberInE(_baseAmount), " wei is ", PriceFormatter.formatPriceInE18(price)));
            quote = price;
        } catch {
            console2.log(string.concat("Failed to quote", PriceFormatter.formatNumberInE(_baseAmount), "wei"));
        }
    }
}
