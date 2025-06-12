// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IWrappedVaultOracle} from "silo-oracles/contracts/interfaces/IWrappedVaultOracle.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol";

library WrappedVaultOraclesConfigsParser {
    string constant public CONFIGS_DIR = "silo-oracles/deploy/wrappedVault/configs/";
    string constant internal _EXTENSION = ".json";

    bytes32 constant internal _EMPTY_STR_HASH = keccak256(abi.encodePacked("\"\""));

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IWrappedVaultOracle.WrappedVaultDeploymentConfig memory config)
    {
        string memory configJson = configFile();

        string memory oracleKey = KV.getString(configJson, _name, "oracle");
        string memory vaultKey = KV.getString(configJson, _name, "vault");


        config.oracle = ISiloOracle(OraclesDeployments.get(_network, oracleKey));
        config.vault = IERC4626(AddrLib.getAddressSafe(_network, vaultKey));
    }

    function configFile() internal view returns (string memory file) {
        file = string.concat(CONFIGS_DIR, ChainsLib.chainAlias(), _EXTENSION);
    }
}
