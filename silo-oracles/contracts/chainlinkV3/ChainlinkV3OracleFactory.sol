// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {OracleFactory} from "../_common/OracleFactory.sol";
import {IChainlinkV3Oracle} from "../interfaces/IChainlinkV3Oracle.sol";
import {ChainlinkV3Oracle} from "../chainlinkV3/ChainlinkV3Oracle.sol";
import {ChainlinkV3OracleConfig} from "../chainlinkV3/ChainlinkV3OracleConfig.sol";
import {OracleNormalization} from "../lib/OracleNormalization.sol";

contract ChainlinkV3OracleFactory is OracleFactory {
    constructor() OracleFactory(address(new ChainlinkV3Oracle())) {
        // noting to configure
    }

    function create(IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory _config)
        external
        virtual
        returns (ChainlinkV3Oracle oracle)
    {
        bytes32 id = hashConfig(_config);
        ChainlinkV3OracleConfig oracleConfig = ChainlinkV3OracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return ChainlinkV3Oracle(getOracleAddress[address(oracleConfig)]);
        }

        uint256 secondaryPriceDecimals = verifyConfig(_config);
        verifyHeartbeat(_config);

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            _config.baseToken, _config.quoteToken, _config.primaryAggregator.decimals(), secondaryPriceDecimals
        );

        oracleConfig = new ChainlinkV3OracleConfig(_config, divider, multiplier);
        oracle = ChainlinkV3Oracle(Clones.clone(ORACLE_IMPLEMENTATION));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    function hashConfig(IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory _config)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }

    function verifyConfig(IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory _config)
        public
        view
        virtual
        returns (uint256 secondaryPriceDecimals)
    {
        if (address(_config.quoteToken) == address(0)) revert IChainlinkV3Oracle.AddressZero();
        if (address(_config.baseToken) == address(0)) revert IChainlinkV3Oracle.AddressZero();
        if (address(_config.quoteToken) == address(_config.baseToken)) revert IChainlinkV3Oracle.TokensAreTheSame();

        if (address(_config.primaryAggregator) == address(0)) revert IChainlinkV3Oracle.AddressZero();

        if (address(_config.primaryAggregator) == address(_config.secondaryAggregator)) {
            revert IChainlinkV3Oracle.AggregatorsAreTheSame();
        }

        if (address(_config.secondaryAggregator) != address(0)) {
            secondaryPriceDecimals = _config.secondaryAggregator.decimals();
        }
    }

    /// @dev heartbeat restrictions are arbitrary
    /// @notice Chainlink's heartbeat is "always" less than a day, except when they late
    function verifyHeartbeat(IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory _config) public pure virtual {
        if (_config.primaryHeartbeat < 30 seconds || _config.primaryHeartbeat > 2 days) {
            revert IChainlinkV3Oracle.InvalidHeartbeat();
        }

        if (address(_config.secondaryAggregator) == address(0)) {
            if (_config.secondaryHeartbeat != 0) revert IChainlinkV3Oracle.InvalidEthHeartbeat();
        } else {
            if (_config.secondaryHeartbeat < 30 seconds || _config.secondaryHeartbeat > 2 days) {
                revert IChainlinkV3Oracle.InvalidEthHeartbeat();
            }
        }
    }
}
