// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";

library ChainlinkV3OraclesConfigsParser {
    string constant public CONFIGS_FILE = "silo-oracles/deploy/chainlink-v3-oracle/_configs.json";

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config)
    {
        string memory baseTokenKey = KV.getString(CONFIGS_FILE, _name, "baseToken");
        string memory quoteTokenKey = KV.getString(CONFIGS_FILE, _name, "quoteToken");
        string memory primaryAggregatorKey = KV.getString(CONFIGS_FILE, _name, "primaryAggregator");
        string memory secondaryAggregatorKey = KV.getString(CONFIGS_FILE, _name, "secondaryAggregator");
        uint256 primaryHeartbeat = KV.getUint(CONFIGS_FILE, _name, "primaryHeartbeat");
        uint256 secondaryHeartbeat = KV.getUint(CONFIGS_FILE, _name, "secondaryHeartbeat");

        require(primaryHeartbeat <= type(uint32).max, "primaryHeartbeat should be uint32");
        require(secondaryHeartbeat <= type(uint32).max, "secondaryHeartbeat should be uint32");

        config = IChainlinkV3Oracle.ChainlinkV3DeploymentConfig({
            baseToken: IERC20Metadata(AddrLib.getAddressSafe(_network, baseTokenKey)),
            quoteToken: IERC20Metadata(AddrLib.getAddressSafe(_network, quoteTokenKey)),
            primaryAggregator: AggregatorV3Interface(AddrLib.getAddressSafe(_network, primaryAggregatorKey)),
            primaryHeartbeat: uint32(primaryHeartbeat),
            secondaryAggregator: AggregatorV3Interface(AddrLib.getAddressSafe(_network, secondaryAggregatorKey)),
            secondaryHeartbeat: uint32(secondaryHeartbeat)
        });
    }
}
