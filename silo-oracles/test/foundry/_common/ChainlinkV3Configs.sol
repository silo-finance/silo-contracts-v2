// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../../constants/Ethereum.sol";

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {TokensGenerator} from "./TokensGenerator.sol";
import {IChainlinkV3Oracle} from "../../../contracts/interfaces/IChainlinkV3Oracle.sol";

abstract contract ChainlinkV3Configs is TokensGenerator {
    function _spellEthChainlinkV3Config(uint256 _divider, uint256 _multiplier)
        internal
        view
        returns (IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory)
    {
        return IChainlinkV3Oracle.ChainlinkV3DeploymentConfig(
            IERC20Metadata(address(tokens["SPELL"])),
            IERC20Metadata(address(tokens["WETH"])),
            AggregatorV3Interface(0x8c110B94C5f1d347fAcF5E1E938AB2db60E3c9a8),
            1 days + 10 minutes,
            AggregatorV3Interface(CHAINLINKV3_ETH_QUOTE_AGGREGATOR),
            1 days + 10 minutes,
            _divider,
            _multiplier,
            true
        );
    }

    function _spellUsdChainlinkV3Config(uint256 _divider, uint256 _multiplier)
        internal
        view
        returns (IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory)
    {
        return IChainlinkV3Oracle.ChainlinkV3DeploymentConfig(
            IERC20Metadata(address(tokens["SPELL"])),
            IERC20Metadata(address(tokens["USDC"])),
            AggregatorV3Interface(0x8c110B94C5f1d347fAcF5E1E938AB2db60E3c9a8),
            1 days + 10 minutes,
            AggregatorV3Interface(address(0)),
            0,
            _divider,
            _multiplier,
            false
        );
    }

    function _dydxChainlinkV3Config(uint256 _divider, uint256 _multiplier) internal view returns (IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory) {
        return IChainlinkV3Oracle.ChainlinkV3DeploymentConfig(
            IERC20Metadata(address(tokens["DYDX"])),
            IERC20Metadata(address(tokens["USDT"])),
            AggregatorV3Interface(0x478909D4D798f3a1F11fFB25E4920C959B4aDe0b),
            0,
            AggregatorV3Interface(address(0)),
            0,
            _divider,
            _multiplier,
            false
        );
    }

    function _printChainlinkV3Setup(IChainlinkV3Oracle.ChainlinkV3Config memory _setup) internal {
        emit log_named_address("aggregator", address(_setup.primaryAggregator));
        emit log_named_address("ethAggregator", address(_setup.secondaryAggregator));
        emit log_named_uint("heartbeat", _setup.primaryHeartbeat);
        emit log_named_uint("ethHeartbeat", _setup.secondaryHeartbeat);
        emit log_named_uint("normalizationDivider", _setup.normalizationDivider);
        emit log_named_uint("normalizationMultiplier", _setup.normalizationMultiplier);
        emit log_named_address("base token", address(_setup.baseToken));
    }
}
