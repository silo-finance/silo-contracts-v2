// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
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

        (
            SiloConfigData.ConfigData memory config,
            ISiloConfig.InitData memory siloInitData,
            address hookReceiverImplementation
        ) = siloData.getConfigData(configName);

        console2.log("[SiloCommonDeploy] Config prepared");

        InterestRateModelConfigData modelData = new InterestRateModelConfigData();

        IInterestRateModelV2.Config memory irmConfigData0 = modelData.getConfigData(config.interestRateModelConfig0);
        IInterestRateModelV2.Config memory irmConfigData1 = modelData.getConfigData(config.interestRateModelConfig1);

        console2.log("[SiloCommonDeploy] IRM configs prepared");
        
        ISiloDeployer.Oracles memory oracles = _getOracles(config, siloData);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));


        console2.log("[SiloCommonDeploy] siloInitData.token0 before", siloInitData.token0);
        console2.log("[SiloCommonDeploy] siloInitData.token1 before", siloInitData.token1);

        hookReceiverImplementation = beforeCreateSilo(siloInitData, hookReceiverImplementation);

        console2.log("[SiloCommonDeploy] `beforeCreateSilo` executed");

        ISiloDeployer siloDeployer = ISiloDeployer(_resolveDeployedContract(SiloCoreContracts.SILO_DEPLOYER));

        vm.startBroadcast(deployerPrivateKey);

        console2.log("[SiloCommonDeploy] siloInitData.token0", siloInitData.token0);
        console2.log("[SiloCommonDeploy] siloInitData.token1", siloInitData.token1);
        console2.log("[SiloCommonDeploy] hookReceiverImplementation", hookReceiverImplementation);

        siloConfig = siloDeployer.deploy(
            oracles,
            irmConfigData0,
            irmConfigData1,
            _getClonableHookReceiverConfig(hookReceiverImplementation),
            siloInitData
        );

        vm.stopBroadcast();

        console2.log("[SiloCommonDeploy] deploy done");

        SiloDeployments.save(getChainAlias(), configName, address(siloConfig));

        _saveOracles(siloConfig, config, siloData.NO_ORACLE_KEY());

        console2.log("[SiloCommonDeploy] run() finished.");
    }

    function _saveOracles(
        ISiloConfig _siloConfig,
        SiloConfigData.ConfigData memory _config,
        bytes32 _noOracleKey
    ) internal {
        (address silo0, address silo1) = _siloConfig.getSilos();

        ISiloConfig.ConfigData memory siloConfig0 = _siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory siloConfig1 = _siloConfig.getConfig(silo1);

        _saveOracle(siloConfig0.solvencyOracle, _config.solvencyOracle0, _noOracleKey);
        _saveOracle(siloConfig0.maxLtvOracle, _config.maxLtvOracle0, _noOracleKey);
        _saveOracle(siloConfig1.solvencyOracle, _config.solvencyOracle1, _noOracleKey);
        _saveOracle(siloConfig1.maxLtvOracle, _config.maxLtvOracle1, _noOracleKey);
    }

    function _saveOracle(address _oracle, string memory _oracleConfigName, bytes32 _noOracleKey) internal {
        bytes32 configHashedKey = keccak256(bytes(_oracleConfigName));

        if (_oracle == address(0) || configHashedKey == _noOracleKey) return;

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
        bytes32 placeHolderKey = _siloData.PLACEHOLDER_KEY();

        oracles = ISiloDeployer.Oracles({
            solvencyOracle0: _getOracleTxData(_config.solvencyOracle0, noOracleKey, placeHolderKey),
            maxLtvOracle0: _getOracleTxData(_config.maxLtvOracle0, noOracleKey, placeHolderKey),
            solvencyOracle1: _getOracleTxData(_config.solvencyOracle1, noOracleKey, placeHolderKey),
            maxLtvOracle1: _getOracleTxData(_config.maxLtvOracle1, noOracleKey, placeHolderKey)
        });
    }

    function _getOracleTxData(string memory _oracleConfigName, bytes32 _noOracleKey, bytes32 placeHolderKey)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        console2.log("[SiloCommonDeploy] verifying an oracle config: ", _oracleConfigName);

        bytes32 configHashedKey = keccak256(bytes(_oracleConfigName));

        if (configHashedKey == _noOracleKey || configHashedKey == placeHolderKey) return txData;

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

    function _resolveDeployedContract(string memory _name) internal returns (address contractAddress) {
        contractAddress = getDeployedAddress(_name);
        console2.log(string.concat("[SiloCommonDeploy] ", _name, " @ %s resolved "), contractAddress);
    }

    function _isUniswapOracle(string memory _oracleConfigName) internal returns (bool isUniswapOracle) {
        address pool = KV.getAddress(
            UniswapV3OraclesConfigsParser.configFile(),
            _oracleConfigName,
            "pool"
        );

        isUniswapOracle = pool != address(0);
    }

    function _isChainlinkOracle(string memory _oracleConfigName) internal returns (bool isChainlinkOracle) {
        address baseToken = KV.getAddress(
            ChainlinkV3OraclesConfigsParser.configFile(),
            _oracleConfigName,
            "baseToken"
        );

        isChainlinkOracle = baseToken != address(0);
    }

    function _isDiaOracle(string memory _oracleConfigName) internal returns (bool isDiaOracle) {
        address diaOracle = KV.getAddress(
            DIAOraclesConfigsParser.configFile(),
            _oracleConfigName,
            "diaOracle"
        );

        isDiaOracle = diaOracle != address(0);
    }

    function beforeCreateSilo(
        ISiloConfig.InitData memory,
        address _hookReceiverImplementation
    ) internal virtual returns (address hookImplementation) {
        hookImplementation = _hookReceiverImplementation;
    }

    function _getClonableHookReceiverConfig(address _implementation)
        internal
        virtual
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver) {
    }
}
