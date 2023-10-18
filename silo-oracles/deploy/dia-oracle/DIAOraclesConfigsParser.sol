// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {IDIAOracle} from "silo-oracles/contracts/interfaces/IDIAOracle.sol";
import {IDIAOracleV2} from "silo-oracles/contracts/external/dia/IDIAOracleV2.sol";

import {console} from "forge-std/console.sol";

library DIAOraclesConfigsParser {
    string constant public CONFIGS_FILE = "silo-oracles/deploy/dia-oracle/_configs.json";

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IDIAOracle.DIADeploymentConfig memory config)
    {
        string memory diaOracleKey = KV.getString(CONFIGS_FILE, _name, "diaOracle");
        string memory baseTokenKey = KV.getString(CONFIGS_FILE, _name, "baseToken");
        string memory quoteTokenKey = KV.getString(CONFIGS_FILE, _name, "quoteToken");
        string memory primaryKey = KV.getString(CONFIGS_FILE, _name, "primaryKey");
        string memory secondaryKey = KV.getString(CONFIGS_FILE, _name, "secondaryKey");
        uint256 heartbeat = KV.getUint(CONFIGS_FILE, _name, "heartbeat");

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
}
