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

        // (
        //     SiloConfigData.ConfigData memory config,
        //     ISiloConfig.InitData memory siloInitData,
        //     address hookReceiverImplementation
        // ) = siloData.getConfigData(configName);

        // console2.log("[SiloCommonDeploy] Config prepared");

        // bytes memory irmConfigData0;
        // bytes memory irmConfigData1;

        // (irmConfigData0, irmConfigData1) = _getIRMConfigData(config, siloInitData);

        // console2.log("[SiloCommonDeploy] IRM configs prepared");

        // ISiloDeployer.Oracles memory oracles = _getOracles(config, siloData);
        // siloInitData.solvencyOracle0 = oracles.solvencyOracle0.deployed;
        // siloInitData.maxLtvOracle0 = oracles.maxLtvOracle0.deployed;
        // siloInitData.solvencyOracle1 = oracles.solvencyOracle1.deployed;
        // siloInitData.maxLtvOracle1 = oracles.maxLtvOracle1.deployed;

        // uint256 deployerPrivateKey = privateKey == 0 ? uint256(vm.envBytes32("PRIVATE_KEY")) : privateKey;

        // console2.log("[SiloCommonDeploy] siloInitData.token0 before", siloInitData.token0);
        // console2.log("[SiloCommonDeploy] siloInitData.token1 before", siloInitData.token1);

        // hookReceiverImplementation = beforeCreateSilo(siloInitData, hookReceiverImplementation);

        // console2.log("[SiloCommonDeploy] `beforeCreateSilo` executed");

        // ISiloDeployer siloDeployer = ISiloDeployer(_resolveDeployedContract(SiloCoreContracts.SILO_DEPLOYER));

        // console2.log("[SiloCommonDeploy] siloInitData.token0", siloInitData.token0);
        // console2.log("[SiloCommonDeploy] siloInitData.token1", siloInitData.token1);
        // console2.log("[SiloCommonDeploy] hookReceiverImplementation", hookReceiverImplementation);

        // ISiloDeployer.ClonableHookReceiver memory hookReceiver;
        // hookReceiver = _getClonableHookReceiverConfig(hookReceiverImplementation);

        // vm.startBroadcast(deployerPrivateKey);

        // siloConfig = siloDeployer.deploy(
        //     oracles,
        //     irmConfigData0,
        //     irmConfigData1,
        //     hookReceiver,
        //     siloInitData
        // );

        // vm.stopBroadcast();

        // console2.log("[SiloCommonDeploy] deploy done");

        // _saveSilo(siloConfig, configName);

        // _saveOracles(siloConfig, config, siloData.NO_ORACLE_KEY());

        // console2.log("[SiloCommonDeploy] run() finished.");

        // _printAndValidateDetails(siloConfig, siloInitData);
    }

    function _saveSilo(ISiloConfig, string memory) internal {
        
    }

    function _saveOracles(ISiloConfig, SiloConfigData.ConfigData memory, bytes32)
        internal pure
    {
        
    }

    function _saveOracle(address, string memory, bytes32) internal pure {
        
    }

    function _getOracles(SiloConfigData.ConfigData memory, SiloConfigData)
        internal
        returns (ISiloDeployer.Oracles memory)
    {
        
    }

    function _getOracleTxData(
        string memory,
        bytes32,
        bytes32
    ) internal returns (ISiloDeployer.OracleCreationTxData memory) {
        
    }

    function _uniswapV3TxData(string memory)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory)
    {
        
    }

    function _chainLinkTxData(string memory)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory)
    {
        
    }

    function _diaTxData(string memory)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory)
    {
        
    }

    function _getIRMConfigData(SiloConfigData.ConfigData memory, ISiloConfig.InitData memory)
        internal
        returns (bytes memory, bytes memory)
    {
        
    }

    function _prepareDKinkIRMConfig(string memory) internal returns (bytes memory) {
        
    }

    function _resolveDeployedContract(string memory) internal returns (address) {
        
    }

    function _isUniswapOracle(string memory) internal returns (bool) {
    }

    function _isChainlinkOracle(string memory) internal returns (bool) {
        
    }

    function _isDiaOracle(string memory) internal returns (bool) {
        
    }

    function beforeCreateSilo(ISiloConfig.InitData memory, address)
        internal
        virtual
        returns (address)
    {
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
