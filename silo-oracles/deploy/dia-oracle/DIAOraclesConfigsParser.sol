// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {IDIAOracle} from "silo-oracles/contracts/interfaces/IDIAOracle.sol";
import {IDIAOracleV2} from "silo-oracles/contracts/external/dia/IDIAOracleV2.sol";

library DIAOraclesConfigsParser {
    string constant public CONFIGS_DIR = "silo-oracles/deploy/dia-oracle/configs/";
    string constant internal _EXTENSION = ".json";

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IDIAOracle.DIADeploymentConfig memory config)
    {
        string memory configJson = configFile();

        string memory diaOracleKey = KV.getString(configJson, _name, "diaOracle");
        string memory baseTokenKey = KV.getString(configJson, _name, "baseToken");
        string memory quoteTokenKey = KV.getString(configJson, _name, "quoteToken");
        string memory primaryKey = KV.getString(configJson, _name, "primaryKey");
        string memory secondaryKey = KV.getString(configJson, _name, "secondaryKey");
        uint256 heartbeat = KV.getUint(configJson, _name, "heartbeat");

        require(heartbeat <= type(uint32).max, "heartbeat should be uint32");

        config = IDIAOracle.DIADeploymentConfig({
            diaOracle: IDIAOracleV2(AddrLib.getAddressSafe(_network, diaOracleKey)),
            baseToken: IERC20Metadata(AddrLib.getAddressSafe(_network, baseTokenKey)),
            quoteToken: IERC20Metadata(AddrLib.getAddressSafe(_network, quoteTokenKey)),
            heartbeat: uint32(heartbeat),
            primaryKey: primaryKey,
            secondaryKey: secondaryKey
        });
    }

    function configFile() internal view returns (string memory file) {
        file = string.concat(CONFIGS_DIR, ChainsLib.chainAlias(), _EXTENSION);
    }
}
