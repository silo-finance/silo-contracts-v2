// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {WrappedVaultOracle} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracle.sol";
import {IWrappedVaultOracle} from "silo-oracles/contracts/interfaces/IWrappedVaultOracle.sol";
import {WrappedVaultOracleFactory} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracleFactory.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";

/**
FOUNDRY_PROFILE=oracles ORACLE=CHAINLINK_USR_USD VAULT=wstUSR \
    forge script silo-oracles/deploy/wrappedVault/WrappedVaultOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract WrappedVaultOracleDeploy is CommonDeploy {
    string private _useOracle;
    string private _useVault;

    function setUseConfig(string memory _vaultName, string memory _oracleName) public {
        _useVault = _vaultName;
        _useOracle = _oracleName;
    }
    
    function run() public returns (WrappedVaultOracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        (IERC4626 useVault, ISiloOracle useOracle, string memory configName) = _parseDeployArgs();

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.WRAPPED_VAULT_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = WrappedVaultOracleFactory(factory).create(useVault, useOracle, bytes32(0));

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), configName, address(oracle));

        console2.log("Config name", configName);

        IWrappedVaultOracle.Config memory cfg = oracle.getConfig();

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

    function _parseDeployArgs() internal returns (IERC4626 vault, ISiloOracle oracle, string memory configName) {
        string memory useVault = bytes(_useVault).length != 0 ? _useVault : vm.envString("VAULT");
        string memory useOracle = bytes(_useOracle).length != 0 ? _useOracle : vm.envString("ORACLE");

        vault = IERC4626(AddrLib.getAddressSafe(getChainAlias(), useVault));
        oracle = ISiloOracle(OraclesDeployments.get(getChainAlias(), useOracle));

        configName = _createDeploymentName(vault, useOracle);
    }

    function _createDeploymentName(IERC4626 _vault, string memory _oracleName)
        internal
        view
        returns (string memory name)
    {
        name = string.concat(
            "WRAPPED_VAULT_",
            IERC20Metadata(address(_vault)).symbol(),
            "_",
            _oracleName
        );
    }
}
