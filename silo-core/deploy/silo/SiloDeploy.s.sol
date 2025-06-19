// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
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
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IsContract} from "silo-core/contracts/lib/IsContract.sol";

/// @dev use `SiloDeployWithDeployerOwner` or `SiloDeployWithHookReceiverOwner`
abstract contract SiloDeploy is CommonDeploy {
    uint256 private constant _BYTES32_SIZE = 32;

    string public configName;
    uint256 public privateKey;

    string[] public verificationIssues;

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

        InterestRateModelConfigData modelData = new InterestRateModelConfigData();

        IInterestRateModelV2.Config memory irmConfigData0 = modelData.getConfigData(config.interestRateModelConfig0);
        IInterestRateModelV2.Config memory irmConfigData1 = modelData.getConfigData(config.interestRateModelConfig1);

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

        SiloDeployments.save(ChainsLib.chainAlias(), configName, address(siloConfig));

        _saveOracles(siloConfig, config, siloData.NO_ORACLE_KEY());

        console2.log("[SiloCommonDeploy] run() finished.");

        _printAndValidateDetails(siloConfig, siloInitData);
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

    function _getOracleTxData(string memory _oracleConfigName, bytes32 _noOracleKey, bytes32 placeHolderKey)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
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

        if (_isUniswapOracle(_oracleConfigName)) {
            console2.log("\t[SiloCommonDeploy] _uniswapV3TxData used for", _oracleConfigName);
            return _uniswapV3TxData(_oracleConfigName);
        }

        if (_isChainlinkOracle(_oracleConfigName)) {
            console2.log("\t[SiloCommonDeploy] _chainLinkTxData used for", _oracleConfigName);
            return _chainLinkTxData(_oracleConfigName);
        }

        revert("[_getOracleTxData] unknown oracle type");
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

        // bytes32(0) is the salt for the create2 call and it will be overridden by the SiloDeployer
        txData.txInput = abi.encodeCall(IUniswapV3Factory.create, (config, bytes32(0)));
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

    function _resolveDeployedContract(string memory _name) internal returns (address contractAddress) {
        contractAddress = SiloCoreDeployments.get(_name, ChainsLib.chainAlias());
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
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver);

    function _printAndValidateDetails(
        ISiloConfig _siloConfig,
        ISiloConfig.InitData memory siloInitData
    ) internal view {
        string memory chainAlias = ChainsLib.chainAlias();

        if (keccak256(bytes(chainAlias)) == keccak256(bytes(ChainsLib.ANVIL_ALIAS))) return;

        (address silo0, address silo1) = _siloConfig.getSilos();

        ISiloConfig.ConfigData memory siloConfig0 = _siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory siloConfig1 = _siloConfig.getConfig(silo1);

        console2.log(string.concat("\nDeployed market details [", chainAlias, "]"));
        console2.log("SiloConfig", address(_siloConfig));
        console2.log("\n");
        console2.log("silo0");
        _printSiloDetails(silo0, siloConfig0, siloInitData, true);
        console2.log("\n");
        console2.log("silo1");
        _printSiloDetails(silo1, siloConfig1, siloInitData, false);
    }

    function _printSiloDetails(
        address _silo,
        ISiloConfig.ConfigData memory _siloConfig,
        ISiloConfig.InitData memory _siloInitData,
        bool _isSilo0
    ) internal view {
        string memory tokenSymbol = TokenHelper.symbol(_siloConfig.token);

        string memory tokenStr = vm.toString(_siloConfig.token);

        uint256 tokenDecimals = TokenHelper.assertAndGetDecimals(_siloConfig.token);

        console2.log(_silo);
        console2.log("\n");

        console2.log(
            "\tasset",
            string.concat(tokenStr, " (", tokenSymbol, ", ", vm.toString(tokenDecimals), " decimals)")
        );

        console2.log("\n");
        console2.log("\tdecimals      ", IERC20Metadata(_silo).decimals());

        string memory icon;
        uint256 configValueUint256 = _siloInitData.daoFee;
        icon = _siloConfig.daoFee != configValueUint256 ? _x_() : _ok_();

        console2.log("\tdaoFee        ", _representAsPercent(_siloConfig.daoFee), icon);

        configValueUint256 = _siloInitData.deployerFee;
        icon = _siloConfig.deployerFee != configValueUint256 ? _x_() : _ok_();   

        console2.log("\tdeployerFee   ", _representAsPercent(_siloConfig.deployerFee), icon);

        configValueUint256 = _isSilo0 ? _siloInitData.liquidationFee0 : _siloInitData.liquidationFee1;
        icon = _siloConfig.liquidationFee != configValueUint256 ? _x_() : _ok_();

        console2.log("\tliquidationFee", _representAsPercent(_siloConfig.liquidationFee), icon);

        configValueUint256 = _isSilo0 ? _siloInitData.flashloanFee0 : _siloInitData.flashloanFee1;
        icon = _siloConfig.flashloanFee != configValueUint256 ? _x_() : _ok_();

        console2.log("\tflashloanFee  ", _representAsPercent(_siloConfig.flashloanFee), icon);
        console2.log("\n");

        configValueUint256 = _isSilo0 ? _siloInitData.maxLtv0 : _siloInitData.maxLtv1;
        icon = _siloConfig.maxLtv != configValueUint256 ? _x_() : _ok_();

        console2.log("\tmaxLtv              ", _representAsPercent(_siloConfig.maxLtv), icon);

        configValueUint256 = _isSilo0 ? _siloInitData.lt0 : _siloInitData.lt1;
        icon = _siloConfig.lt != configValueUint256 ? _x_() : _ok_();

        console2.log("\tlt                  ", _representAsPercent(_siloConfig.lt), icon);

        configValueUint256 = _isSilo0 ? _siloInitData.liquidationTargetLtv0 : _siloInitData.liquidationTargetLtv1;
        icon = _siloConfig.liquidationTargetLtv != configValueUint256 ? _x_() : _ok_();

        if (_siloConfig.liquidationTargetLtv == _siloConfig.lt) {
            icon = string.concat(_warn_(), "!!! WARNING !!!");
        }

        console2.log(
            "\tliquidationTargetLtv",
            _representAsPercent(_siloConfig.liquidationTargetLtv),
            icon
        );

        console2.log("\n");
        console2.log("\tsolvencyOracle", _siloConfig.solvencyOracle);

        if (_siloConfig.solvencyOracle != address(0)) {
            _printOracleInfo(_siloConfig.solvencyOracle, _siloConfig.token);
        }

        console2.log("\tmaxLtvOracle", _siloConfig.maxLtvOracle);

        if (_siloConfig.maxLtvOracle != address(0)) {
            _printOracleInfo(_siloConfig.maxLtvOracle, _siloConfig.token);
        }
    }

    function _printOracleInfo(address _oracle, address _asset) internal view {
        ISiloOracle oracle = ISiloOracle(_oracle);

        address quoteToken = oracle.quoteToken();
        string memory quoteTokenSymbol = _symbol(quoteToken);
        uint256 quoteTokenDecimals = _assertAndGetDecimals(quoteToken);

        console2.log(
            "\t\tquoteToken",
            string.concat(
                vm.toString(quoteToken),
                " (",
                quoteTokenSymbol,
                ", ",
                vm.toString(quoteTokenDecimals),
                " decimals)"
            )
        );

        uint256 assetDecimals = _assertAndGetDecimals(_asset);

        if (assetDecimals != 0) {
            uint256 quoteTokenPrice = oracle.quote(10 ** assetDecimals, _asset);
            console2.log("\t\tquote", quoteTokenPrice);
        }
    }

    function _representAsPercent(uint256 _fee) internal pure returns (string memory percent) {
        if (_fee == 0) return "0%";

        uint256 biasPoints = _fee * 1e4 / 1e18;

        if (biasPoints == 0) return "0%";

        if (biasPoints < 10) {
            percent = string.concat("0.0", vm.toString(biasPoints));
        } else if (biasPoints < 100) {
            uint256 biasPointsInTenths = biasPoints / 10;
            uint256 reminder = biasPoints - biasPointsInTenths * 10;

            percent = string.concat("0.", vm.toString(biasPointsInTenths));

            if (reminder != 0) {
                percent = string.concat(percent, vm.toString(reminder));
            }
        } else {
            uint256 biasPointsInHundredths = biasPoints / 100;
            uint256 reminder = biasPoints - biasPointsInHundredths * 100;

            percent = vm.toString(biasPointsInHundredths);

            if (reminder != 0) {
                percent = string.concat(percent, ".", vm.toString(reminder));
            }
        }

        percent = string.concat(percent, "%");
    }

    function _assertAndGetDecimals(address _token) internal view returns (uint256) {
        (bool hasMetadata, bytes memory data) =
            _tokenMetadataCall(_token, abi.encodeCall(IERC20Metadata.decimals, ()));

        // decimals() is optional in the ERC20 standard, so if metadata is not accessible
        // we assume there are no decimals and use 0.
        if (!hasMetadata) {
            return 0;
        }

        return abi.decode(data, (uint8));
    }

    /// @dev Performs a staticcall to the token to get its metadata (symbol, decimals, name)
    function _tokenMetadataCall(address _token, bytes memory _data) private view returns (bool, bytes memory) {
        if (!IsContract.isContract(_token)) return (false, "");

        (bool success, bytes memory result) = _token.staticcall(_data);

        // If the call reverted we assume the token doesn't follow the metadata extension
        if (!success) {
            return (false, "");
        }

        return (true, result);
    }

    function _symbol(address _token) internal view returns (string memory assetSymbol) {
        (bool hasMetadata, bytes memory data) =
            _tokenMetadataCall(_token, abi.encodeCall(IERC20Metadata.symbol, ()));

        if (!hasMetadata || data.length == 0) {
            return "?";
        } else if (data.length == _BYTES32_SIZE) {
            return string(TokenHelper.removeZeros(data));
        } else {
            return abi.decode(data, (string));
        }
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
