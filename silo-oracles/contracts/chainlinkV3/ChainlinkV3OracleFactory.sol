// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {OracleFactory} from "../_common/OracleFactory.sol";
import {IChainlinkV3Oracle} from "../interfaces/IChainlinkV3Oracle.sol";
import {ChainlinkV3Oracle} from "../chainlinkV3/ChainlinkV3Oracle.sol";
import {ChainlinkV3OracleConfig} from "../chainlinkV3/ChainlinkV3OracleConfig.sol";
import {OracleNormalization} from "../lib/OracleNormalization.sol";

contract ChainlinkV3OracleFactory is OracleFactory {
    /// @dev price provider needs to return prices in ETH, but assets prices provided by DIA are in USD
    /// Under ETH_USD_KEY we will find ETH price in USD so we can convert price in USD into price in ETH
    string internal constant _ETH_USD_KEY = "ETH/USD";

    /// @dev decimals in DIA oracle
    uint256 internal constant _DIA_DECIMALS = 8;

    /// @dev address that will be used to determine, if token address is ETH
    /// Chainlink is not operating based on addresses, so this can be any address eg WETH or 0xEeEe...
    address internal immutable _ETH_ADDRESS; // solhint-disable-line var-name-mixedcase

    constructor(address _ethAddress) OracleFactory(address(new ChainlinkV3Oracle())) {
        if (_ethAddress == address(0)) revert IChainlinkV3Oracle.AddressZero();

        _ETH_ADDRESS = _ethAddress;
    }

    function create(IChainlinkV3Oracle.ChainlinkV3OracleInitConfig memory _config)
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

        verifyTokens(_config);
        uint256 ethPriceDecimals = verifyAggregators(_config);
        verifyHeartbeat(_config);

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            _config.baseToken, _config.quoteToken, _config.aggregator.decimals(), ethPriceDecimals
        );

        oracleConfig = new ChainlinkV3OracleConfig(_config, divider, multiplier);
        oracle = ChainlinkV3Oracle(ClonesUpgradeable.clone(ORACLE_IMPLEMENTATION));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    /// @return key
    /// @return decimals in DIA oracle
    /// @return ethAddress address that will be used to determine, if token address is ETH
    /// Chainlink is not operating based on addresses, so this can be any address eg WETH
    function setup() external view virtual returns (string memory key, uint256 decimals, address ethAddress) {
        key = _ETH_USD_KEY;
        decimals = _DIA_DECIMALS;
        ethAddress = _ETH_ADDRESS;
    }

    function hashConfig(IChainlinkV3Oracle.ChainlinkV3OracleInitConfig memory _config)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }

    /// @dev there are two cases of verifications:
    /// 1. where we only have one aggregator:
    ///   - this can be any aggregators and tokens symbols must match it description
    ///   - OR it can be /USD aggregator, then we check if quote symbol match known stablecoins
    /// 2. when we have two aggregators: in this case we will be conversing price to ETH by using ETH/USD aggregator.
    ///   main aggregator must provide price denominator in USD
    function verifyTokens(IChainlinkV3Oracle.ChainlinkV3OracleInitConfig memory _config) public view virtual {
        string memory baseSymbol = _config.baseToken.symbol();
        bytes32 aggregatorDesc = keccak256(abi.encodePacked(_config.aggregator.description()));

        if (address(_config.ethAggregator) == address(0)) {
            string memory quoteSymbol = _config.quoteToken.symbol();

            if (aggregatorDesc == keccak256(abi.encodePacked(baseSymbol, " / USD"))) {
                verifyStablecoin(quoteSymbol);
            } else if (aggregatorDesc != keccak256(abi.encodePacked(baseSymbol, " / ", quoteSymbol))) {
                revert IChainlinkV3Oracle.AggregatorDesciptionNotMatch();
            }
        } else {
            if (aggregatorDesc != keccak256(abi.encodePacked(baseSymbol, " / USD"))) {
                revert IChainlinkV3Oracle.AggregatorDesciptionNotMatch();
            }

            bytes32 ethAggregatorDesc = keccak256(abi.encodePacked(_config.ethAggregator.description()));

            if (ethAggregatorDesc != keccak256(abi.encodePacked("ETH / USD"))) {
                revert IChainlinkV3Oracle.EthAggregatorDesciptionNotMatch();
            }
        }
    }

    function verifyAggregators(IChainlinkV3Oracle.ChainlinkV3OracleInitConfig memory _config)
        public
        view
        virtual
        returns (uint256 ethPriceDecimals)
    {
        if (address(_config.ethAggregator) != address(0)) {
            ethPriceDecimals = _config.ethAggregator.decimals();
            if (address(_config.quoteToken) != _ETH_ADDRESS) revert IChainlinkV3Oracle.QuoteTokenNotMatchEth();
        }
    }

    /// @dev heartbeat restrictions are arbitrary
    /// @notice Chainlink's heartbeat is "always" less than a day, except when they late
    function verifyHeartbeat(IChainlinkV3Oracle.ChainlinkV3OracleInitConfig memory _config) public view virtual {
        if (_config.heartbeat < 60 seconds || _config.heartbeat > 2 days) revert IChainlinkV3Oracle.InvalidHeartbeat();

        if (address(_config.ethAggregator) == address(0)) {
            if (_config.ethHeartbeat != 0) revert IChainlinkV3Oracle.InvalidEthHeartbeat();
        } else {
            if (_config.ethHeartbeat < 60 seconds || _config.ethHeartbeat > 2 days) {
                revert IChainlinkV3Oracle.InvalidEthHeartbeat();
            }
        }
    }
}
