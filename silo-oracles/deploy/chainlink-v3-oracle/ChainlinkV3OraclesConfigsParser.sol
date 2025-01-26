// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";

library ChainlinkV3OraclesConfigsParser {
    string constant public CONFIGS_DIR = "silo-oracles/deploy/chainlink-v3-oracle/configs/";
    string constant internal _EXTENSION = ".json";

    bytes32 constant internal _EMPTY_STR_HASH = keccak256(abi.encodePacked("\"\""));

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config)
    {
        string memory configJson = configFile();

        string memory baseTokenKey = KV.getString(configJson, _name, "baseToken");
        string memory quoteTokenKey = KV.getString(configJson, _name, "quoteToken");
        string memory primaryAggregatorKey = KV.getString(configJson, _name, "primaryAggregator");
        string memory secondaryAggregatorKey = KV.getString(configJson, _name, "secondaryAggregator");

        {
            uint256 primaryHeartbeat = KV.getUint(configJson, _name, "primaryHeartbeat");
            require(primaryHeartbeat <= type(uint32).max, "primaryHeartbeat should be uint32");
            config.primaryHeartbeat = uint32(primaryHeartbeat);

            uint256 secondaryHeartbeat = KV.getUint(configJson, _name, "secondaryHeartbeat");
            require(secondaryHeartbeat <= type(uint32).max, "secondaryHeartbeat should be uint32");
            config.secondaryHeartbeat = uint32(secondaryHeartbeat);
        }

        config.normalizationDivider = KV.getUint(configJson, _name, "normalizationDivider");
        config.normalizationMultiplier = KV.getUint(configJson, _name, "normalizationMultiplier");
        config.invertSecondPrice = KV.getBoolean(configJson, _name, "invertSecondPrice");

        require(config.normalizationDivider <= 1e36, "normalizationDivider is over 1e36");
        require(config.normalizationMultiplier <= 1e36, "normalizationMultiplier is over 1e36");
        require(config.normalizationDivider != 0 || config.normalizationMultiplier != 0, "normalization variables not set");

        AggregatorV3Interface secondaryAggregator = AggregatorV3Interface(address(0));

        if (keccak256(abi.encodePacked(secondaryAggregatorKey)) != _EMPTY_STR_HASH) {
            secondaryAggregator = AggregatorV3Interface(AddrLib.getAddressSafe(_network, secondaryAggregatorKey));
        }

        config.baseToken = IERC20Metadata(AddrLib.getAddressSafe(_network, baseTokenKey));
        config.quoteToken = IERC20Metadata(AddrLib.getAddressSafe(_network, quoteTokenKey));
        config.primaryAggregator = AggregatorV3Interface(AddrLib.getAddressSafe(_network, primaryAggregatorKey));
        config.secondaryAggregator = secondaryAggregator;
    }

    function configFile() internal view returns (string memory file) {
        file = string.concat(CONFIGS_DIR, ChainsLib.chainAlias(), _EXTENSION);
    }
}
