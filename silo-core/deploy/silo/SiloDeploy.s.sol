// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {InterestRateModelConfigData} from "../input-readers/InterestRateModelConfigData.sol";
import {DKinkIRMConfigData} from "../input-readers/DKinkIRMConfigData.sol";
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
import {ChainlinkV3OraclesConfigsParser} from
    "silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OraclesConfigsParser.sol";
import {
    SiloOraclesFactoriesContracts,
    SiloOraclesFactoriesDeployments
} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol";
import {PTLinearOracleTxLib} from "../lib/PTLinearOracleTxLib.sol";

/// @dev use `SiloDeployWithDeployerOwner` or `SiloDeployWithHookReceiverOwner`
abstract contract SiloDeploy is CommonDeploy {
    string public configName;
    uint256 public privateKey;

    string[] public verificationIssues;

    error UnknownInterestRateModelFactory();

    function useConfig(string memory _config) external returns (SiloDeploy) {
        configName = _config;
        return this;
    }

    function usePrivateKey(uint256 _privateKey) external returns (SiloDeploy) {
        privateKey = _privateKey;
        return this;
    }

    function run() public virtual returns (ISiloConfig siloConfig) {
        console2.log("[SiloCommonDeploy] run()");

        SiloConfigData siloData = new SiloConfigData();
        console2.log("[SiloCommonDeploy] SiloConfigData deployed");

        configName = bytes(configName).length == 0 ? vm.envString("CONFIG") : configName;

        console2.log("[SiloCommonDeploy] using CONFIG: ", configName);

        (
            SiloConfigData.ConfigData memory config,
            ISiloConfig.InitData memory siloInitData,
            address hookReceiverImplementation
        ) = siloData.getConfigData(configName);

        console2.log("[SiloCommonDeploy] Config prepared");

        bytes memory irmConfigData0;
        bytes memory irmConfigData1;

        (irmConfigData0, irmConfigData1) = _getIRMConfigData(config, siloInitData);

        console2.log("[SiloCommonDeploy] IRM configs prepared");

        ISiloDeployer.Oracles memory oracles = _getOracles(config, siloData);
        siloInitData.solvencyOracle0 = oracles.solvencyOracle0.deployed;
        siloInitData.maxLtvOracle0 = oracles.maxLtvOracle0.deployed;
        siloInitData.solvencyOracle1 = oracles.solvencyOracle1.deployed;
        siloInitData.maxLtvOracle1 = oracles.maxLtvOracle1.deployed;

        uint256 deployerPrivateKey = privateKey == 0 ? uint256(vm.envBytes32("PRIVATE_KEY")) : privateKey;

        console2.log("[SiloCommonDeploy] siloInitData.token0 before", siloInitData.token0);
        console2.log("[SiloCommonDeploy] siloInitData.token1 before", siloInitData.token1);

        hookReceiverImplementation = beforeCreateSilo(siloInitData, hookReceiverImplementation);

        console2.log("[SiloCommonDeploy] `beforeCreateSilo` executed");

        ISiloDeployer siloDeployer = ISiloDeployer(_resolveDeployedContract(SiloCoreContracts.SILO_DEPLOYER));

        console2.log("[SiloCommonDeploy] siloInitData.token0", siloInitData.token0);
        console2.log("[SiloCommonDeploy] siloInitData.token1", siloInitData.token1);
        console2.log("[SiloCommonDeploy] hookReceiverImplementation", hookReceiverImplementation);

        ISiloDeployer.ClonableHookReceiver memory hookReceiver;
        hookReceiver = _getClonableHookReceiverConfig(hookReceiverImplementation);

        vm.startBroadcast(deployerPrivateKey);

        siloConfig = siloDeployer.deploy(
            oracles,
            irmConfigData0,
            irmConfigData1,
            hookReceiver,
            siloInitData
        );

        vm.stopBroadcast();

        console2.log("[SiloCommonDeploy] deploy done");

        _saveSilo(siloConfig, configName);

        _saveOracles(siloConfig, config, siloData.NO_ORACLE_KEY());

        console2.log("[SiloCommonDeploy] run() finished.");

        _printAndValidateDetails(siloConfig, siloInitData);
    }

    function _saveSilo(ISiloConfig _siloConfig, string memory _configName) internal {
        SiloDeployments.save({
            _chain: ChainsLib.chainAlias(),
            _name: string.concat(_configName, "_id_", vm.toString(_siloConfig.SILO_ID())),
            _deployed: address(_siloConfig)
        });
    }

    function _saveOracles(ISiloConfig _siloConfig, SiloConfigData.ConfigData memory _config, bytes32 _noOracleKey)
        internal
    {
        (address silo0, address silo1) = _siloConfig.getSilos();

        ISiloConfig.ConfigData memory siloConfig0 = _siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory siloConfig1 = _siloConfig.getConfig(silo1);

        _saveOracle(siloConfig0.solvencyOracle, _config.solvencyOracle0, _noOracleKey);
        _saveOracle(siloConfig0.maxLtvOracle, _config.maxLtvOracle0, _noOracleKey);
        _saveOracle(siloConfig1.solvencyOracle, _config.solvencyOracle1, _noOracleKey);
        _saveOracle(siloConfig1.maxLtvOracle, _config.maxLtvOracle1, _noOracleKey);
    }

    function _saveOracle(address _oracle, string memory _oracleConfigName, bytes32 _noOracleKey) internal {
        console2.log("[_saveOracle] _oracle", _oracle);
        console2.log("[_saveOracle] _oracleConfigName", _oracleConfigName);

        bytes32 configHashedKey = keccak256(bytes(_oracleConfigName));

        if (configHashedKey == _noOracleKey) return;

        string memory chainAlias = ChainsLib.chainAlias();
        address oracleFromDeployments = OraclesDeployments.get(chainAlias, _oracleConfigName);

        if (oracleFromDeployments != address(0)) {
            if (oracleFromDeployments != _oracle) {
                console2.log(
                    string.concat(_warn_(), "we have deployment address for %s, but it was deployed again at %s"),
                    _oracleConfigName,
                    _oracle,
                    _warn_()
                );

                revert(string.concat("unnecessary redeployment of ", _oracleConfigName));
            }
        }

        if (_oracle == address(0)) {
            console2.log("missing deployment for %s", _oracleConfigName, _x_());
            return;
        }

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

    function _getOracleTxData(
        string memory _oracleConfigName,
        bytes32 _noOracleKey,
        bytes32 placeHolderKey
    ) internal returns (ISiloDeployer.OracleCreationTxData memory txData) {
        console2.log("[SiloCommonDeploy] _getOracleTxData for config: ", _oracleConfigName);

        bytes32 configHashedKey = keccak256(bytes(_oracleConfigName));

        if (configHashedKey == _noOracleKey || configHashedKey == placeHolderKey) {
            console2.log("\t[SiloCommonDeploy] no deployment required for", _oracleConfigName);
            return txData;
        }

        address deployed = SiloCoreDeployments.parseAddress(_oracleConfigName);
        console2.log("\ttry to parse name to address: %s", deployed);

        if (deployed != address(0)) {
            txData.deployed = deployed;
            console2.log("\tusing already deployed oracle with fixed address: %s", _oracleConfigName, deployed);
            return txData;
        }

        deployed = OraclesDeployments.get(ChainsLib.chainAlias(), _oracleConfigName);
        console2.log("\tOraclesDeployments: %s", deployed);

        if (deployed != address(0)) {
            txData.deployed = deployed;
            console2.log("\tusing already deployed oracle %s: %s", _oracleConfigName, deployed);
            return txData;
        }

        require(txData.deployed == address(0), "[_getOracleTxData] at this point we need to create NEW deployment");

        if (_isUniswapOracle(_oracleConfigName)) {
            console2.log(
                "\t[SiloCommonDeploy] NEW oracle will be deployed using UniswapV3OracleTxData for: ",
                _oracleConfigName
            );

            txData = _uniswapV3TxData(_oracleConfigName);
        } else if (_isChainlinkOracle(_oracleConfigName)) {
            console2.log(
                "\t[SiloCommonDeploy] NEW oracle will be deployed using ChainlinkV3OracleTxData for: ",
                _oracleConfigName
            );

            txData = _chainLinkTxData(_oracleConfigName);
        } else if (PTLinearOracleTxLib.isPendleLinearOracle(_oracleConfigName)) {
            console2.log(
                "\t[SiloCommonDeploy] NEW oracle will be deployed using PendleLinearOracleTxData for: ",
                _oracleConfigName
            );

            txData = PTLinearOracleTxLib.pendleLinearOracleTxData(_oracleConfigName);
        } else {
            revert(string.concat("[_getOracleTxData] ERROR unknown oracle type: ", _oracleConfigName));
        }

        require(txData.deployed == address(0), "[_getOracleTxData] expect tx data, not deployed address");
        require(txData.factory != address(0), string.concat("[_getOracleTxData] empty factory for oracle: ", _oracleConfigName));
        require(txData.txInput.length != 0, string.concat("[_getOracleTxData] missing tx data for oracle: ", _oracleConfigName));
    }

    function _uniswapV3TxData(string memory _oracleConfigName)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        string memory chainAlias = ChainsLib.chainAlias();

        txData.factory =
            SiloOraclesFactoriesDeployments.get(SiloOraclesFactoriesContracts.UNISWAP_V3_ORACLE_FACTORY, chainAlias);

        IUniswapV3Oracle.UniswapV3DeploymentConfig memory config =
            UniswapV3OraclesConfigsParser.getConfig(chainAlias, _oracleConfigName);

        // bytes32(0) is the salt for the create2 call and it will be overridden by the SiloDeployer
        txData.txInput = abi.encodeCall(IUniswapV3Factory.create, (config, bytes32(0)));
    }

    function _chainLinkTxData(string memory _oracleConfigName)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        string memory chainAlias = ChainsLib.chainAlias();

        txData.factory =
            SiloOraclesFactoriesDeployments.get(SiloOraclesFactoriesContracts.CHAINLINK_V3_ORACLE_FACTORY, chainAlias);

        IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config =
            ChainlinkV3OraclesConfigsParser.getConfig(chainAlias, _oracleConfigName);

        // bytes32(0) is the salt for the create2 call and it will be overridden by the SiloDeployer
        txData.txInput = abi.encodeCall(IChainlinkV3Factory.create, (config, bytes32(0)));
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

        // bytes32(0) is the salt for the create2 call and it will be overridden by the SiloDeployer
        txData.txInput = abi.encodeCall(IDIAOracleFactory.create, (config, bytes32(0)));
    }

    function _getIRMConfigData(SiloConfigData.ConfigData memory, ISiloConfig.InitData memory)
        internal
        returns (bytes memory, bytes memory)
    {
        
    }

    function _prepareDKinkIRMConfig(string memory _configName) internal returns (bytes memory irmConfigData) {
        DKinkIRMConfigData dkinkIRMModelData = new DKinkIRMConfigData();

        (
            IDynamicKinkModel.Config memory dkinkIRMConfigData, 
            IDynamicKinkModel.ImmutableArgs memory immutableArgs
        ) = dkinkIRMModelData.getConfigData(_configName);

        ISiloDeployer.DKinkIRMConfig memory dkinkIRMConfig = ISiloDeployer.DKinkIRMConfig({
            config: dkinkIRMConfigData,
            immutableArgs: immutableArgs,
            initialOwner: _getDKinkIRMInitialOwner()
        });

        irmConfigData = abi.encode(dkinkIRMConfig);
    }

    function _resolveDeployedContract(string memory _name) internal returns (address contractAddress) {
        contractAddress = SiloCoreDeployments.get(_name, ChainsLib.chainAlias());
        console2.log(string.concat("[SiloCommonDeploy] ", _name, " @ %s resolved "), contractAddress);
    }

    function _isUniswapOracle(string memory _oracleConfigName) internal returns (bool isUniswapOracle) {
        address pool = KV.getAddress(UniswapV3OraclesConfigsParser.configFile(), _oracleConfigName, "pool");

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
        address diaOracle = KV.getAddress(DIAOraclesConfigsParser.configFile(), _oracleConfigName, "diaOracle");

        isDiaOracle = diaOracle != address(0);
    }

    function beforeCreateSilo(ISiloConfig.InitData memory, address _hookReceiverImplementation)
        internal
        virtual
        returns (address hookImplementation)
    {
        hookImplementation = _hookReceiverImplementation;
    }

    function _getClonableHookReceiverConfig(address _implementation)
        internal
        virtual
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver);

    function _getDKinkIRMInitialOwner() internal virtual returns (address);

    function _printAndValidateDetails(ISiloConfig, ISiloConfig.InitData memory)
        internal
        view
    {
        
    }

    function _printSiloDetails(
        address,
        ISiloConfig.ConfigData memory,
        ISiloConfig.InitData memory,
        bool
    ) internal view {
        
    }

    function _printOracleInfo(address, address) internal view {
        
    }

    function _representAsPercent(uint256) internal pure returns (string memory) {
        
    }

    function _assertAndGetDecimals(address) internal view returns (uint256) {
        
    }

    /// @dev Performs a staticcall to the token to get its metadata (symbol, decimals, name)
    function _tokenMetadataCall(address, bytes memory) private view returns (bool, bytes memory) {
        
    }

    function _symbol(address) internal view returns (string memory) {
        
    }

    function _x_() internal pure virtual returns (string memory) {
        return string.concat(unicode"❌", " ");
    }

    function _ok_() internal pure virtual returns (string memory) {
        return string.concat(unicode"✅", " ");
    }

    function _warn_() internal pure virtual returns (string memory) {
        return string.concat(unicode"🚸", " ");
    }
}
