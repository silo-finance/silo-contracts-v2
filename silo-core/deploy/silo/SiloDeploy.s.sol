// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {console2} from "forge-std/console2.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy, SiloCoreContracts} from "../_CommonDeploy.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2ConfigFactory} from "silo-core/contracts/interfaces/IInterestRateModelV2ConfigFactory.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelConfigData} from "../input-readers/InterestRateModelConfigData.sol";
import {SiloConfigData, ISiloConfig} from "../input-readers/SiloConfigData.sol";
import {SiloDeployments} from "./SiloDeployments.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {UniswapV3OraclesConfigsParser} from "silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OraclesConfigsParser.sol";
import {DIAOraclesConfigsParser} from "silo-oracles/deploy/dia-oracle/DIAOraclesConfigsParser.sol";
import {IUniswapV3Oracle} from "silo-oracles/contracts/interfaces/IUniswapV3Oracle.sol";
import {IUniswapV3Factory} from "silo-oracles/contracts/interfaces/IUniswapV3Factory.sol";
import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";
import {IChainlinkV3Factory} from "silo-oracles/contracts/interfaces/IChainlinkV3Factory.sol";
import {IDIAOracle} from "silo-oracles/contracts/interfaces/IDIAOracle.sol";
import {IDIAOracleFactory} from "silo-oracles/contracts/interfaces/IDIAOracleFactory.sol";
import {
    ChainlinkV3OraclesConfigsParser
} from "silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OraclesConfigsParser.sol";
import {
    SiloOraclesFactoriesContracts,
    SiloOraclesFactoriesDeployments
} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol"; 

/**
FOUNDRY_PROFILE=core CONFIG=USDC_UniswapV3_Silo \
    forge script silo-core/deploy/silo/SiloDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDeploy is CommonDeploy {
    string internal _configName;

    function useConfig(string memory _config) external returns (SiloDeploy) {
        _configName = _config;
        return this;
    }

    function run() public returns (ISiloConfig siloConfig) {
        console2.log("[SiloCommonDeploy] run()");

        SiloConfigData siloData = new SiloConfigData();
        console2.log("[SiloCommonDeploy] SiloConfigData deployed");

        string memory configName = bytes(_configName).length == 0 ? vm.envString("CONFIG") : _configName;

        console2.log("[SiloCommonDeploy] using CONFIG: ", configName);

        (SiloConfigData.ConfigData memory config, ISiloConfig.InitData memory siloInitData) =
            siloData.getConfigData(configName);

        console2.log("[SiloCommonDeploy] Config prepared");

        address interestRateModel = getDeployedAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2);

        console2.log("[SiloCommonDeploy] SILO_DEPLOYER and INTEREST_RATE_MODEL_V2 resolved");

        siloInitData.interestRateModel0 = interestRateModel;
        siloInitData.interestRateModel1 = interestRateModel;

        InterestRateModelConfigData modelData = new InterestRateModelConfigData();

        IInterestRateModelV2.Config memory irmConfigData0 = modelData.getConfigData(config.interestRateModelConfig0);
        IInterestRateModelV2.Config memory irmConfigData1 = modelData.getConfigData(config.interestRateModelConfig1);

        console2.log("[SiloCommonDeploy] IRM configs prepared");
        
        ISiloDeployer.Oracles memory oracles = _getOracles(config, siloData);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        beforeCreateSilo(siloInitData);

        console2.log("[SiloCommonDeploy] `beforeCreateSilo` executed");

        ISiloDeployer deployer = ISiloDeployer(getDeployedAddress(SiloCoreContracts.SILO_DEPLOYER));

        siloConfig = deployer.deploy(
            oracles,
            irmConfigData0,
            irmConfigData1,
            siloInitData
        );

        console2.log("[SiloCommonDeploy] deploy done");

        vm.stopBroadcast();

        SiloDeployments.save(getChainAlias(), configName, address(siloConfig));

        _saveOracles(siloConfig, config);

        console2.log("[SiloCommonDeploy] run() finished.");
    }

    function _saveOracles(
        ISiloConfig _siloConfig,
        SiloConfigData.ConfigData memory _config
    ) internal {
        (address silo0, address silo1) = _siloConfig.getSilos();

        ISiloConfig.ConfigData memory siloConfig0 = _siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory siloConfig1 = _siloConfig.getConfig(silo1);

        _saveOracle(siloConfig0.solvencyOracle, _config.solvencyOracle0);
        _saveOracle(siloConfig0.maxLtvOracle, _config.maxLtvOracle0);
        _saveOracle(siloConfig1.solvencyOracle, _config.solvencyOracle1);
        _saveOracle(siloConfig1.maxLtvOracle, _config.maxLtvOracle1);
    }

    function _saveOracle(address _oracle, string memory _oracleConfigName) internal {
        if (_oracle == address(0)) return;

        string memory chainAlias = ChainsLib.chainAlias();
        address oracleFromDeployments = OraclesDeployments.get(chainAlias, _oracleConfigName);

        if (oracleFromDeployments != address(0)) return;

        OraclesDeployments.save(chainAlias, _oracleConfigName, _oracle);
    }

    function _getOracles(SiloConfigData.ConfigData memory _config, SiloConfigData _siloData)
        internal
        returns (ISiloDeployer.Oracles memory oracles)
    {
        bytes32 noOracleKey = _siloData.NO_ORACLE_KEY();

        oracles = ISiloDeployer.Oracles({
            solvencyOracle0: _getOracleTxData(_config.solvencyOracle0, noOracleKey),
            maxLtvOracle0: _getOracleTxData(_config.maxLtvOracle0, noOracleKey),
            solvencyOracle1: _getOracleTxData(_config.solvencyOracle1, noOracleKey),
            maxLtvOracle1: _getOracleTxData(_config.maxLtvOracle1, noOracleKey)
        });
    }

    function _getOracleTxData(string memory _oracleConfigName, bytes32 _noOracleKey)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        console2.log("[SiloCommonDeploy] verifying an oracle config: ", _oracleConfigName);

        if (keccak256(bytes(_oracleConfigName)) == _noOracleKey) return txData;

        if (_isUniswapOracle(_oracleConfigName)) {
            return _uniswapV3TxData(_oracleConfigName);
        }

        if (_isChainlinkOracle(_oracleConfigName)) {
            return _chainLinkTxData(_oracleConfigName);
        }

        if (_isDiaOracle(_oracleConfigName)) {
            return _diaTxData(_oracleConfigName);
        }
    }

    function _uniswapV3TxData(string memory _oracleConfigName)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        string memory chainAlias = ChainsLib.chainAlias();

        txData.factory = SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.UNISWAP_V3_ORACLE_FACTORY,
            chainAlias
        );

        IUniswapV3Oracle.UniswapV3DeploymentConfig memory config = UniswapV3OraclesConfigsParser.getConfig(
            chainAlias,
            _oracleConfigName
        );

        txData.txInput = abi.encodeCall(IUniswapV3Factory.create, config);
    }

    function _chainLinkTxData(string memory _oracleConfigName)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        string memory chainAlias = ChainsLib.chainAlias();

        txData.factory = SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.CHAINLINK_V3_ORACLE_FACTORY,
            chainAlias
        );

        IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config = ChainlinkV3OraclesConfigsParser.getConfig(
            chainAlias,
            _oracleConfigName
        );

        txData.txInput = abi.encodeCall(IChainlinkV3Factory.create, config);
    }

    function _diaTxData(string memory _oracleConfigName)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        string memory chainAlias = ChainsLib.chainAlias();

        txData.factory = SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.DIA_ORACLE_FACTORY,
            chainAlias
        );

        IDIAOracle.DIADeploymentConfig memory config = DIAOraclesConfigsParser.getConfig(
            chainAlias,
            _oracleConfigName
        );

        txData.txInput = abi.encodeCall(IDIAOracleFactory.create, config);
    }

    function _isUniswapOracle(string memory _oracleConfigName) internal returns (bool isUniswapOracle) {
        address pool = KV.getAddress(
            UniswapV3OraclesConfigsParser.CONFIGS_FILE,
            _oracleConfigName,
            "pool"
        );

        isUniswapOracle = pool != address(0);
    }

    function _isChainlinkOracle(string memory _oracleConfigName) internal returns (bool isChainlinkOracle) {
        address baseToken = KV.getAddress(
            ChainlinkV3OraclesConfigsParser.CONFIGS_FILE,
            _oracleConfigName,
            "baseToken"
        );

        isChainlinkOracle = baseToken != address(0);
    }

    function _isDiaOracle(string memory _oracleConfigName) internal returns (bool isDiaOracle) {
        address diaOracle = KV.getAddress(
            DIAOraclesConfigsParser.CONFIGS_FILE,
            _oracleConfigName,
            "diaOracle"
        );

        isDiaOracle = diaOracle != address(0);
    }

    function beforeCreateSilo(ISiloConfig.InitData memory) internal virtual {
        // hook for any action before creating silo
    }
}
