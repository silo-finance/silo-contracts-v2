// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";
import {IPTLinearOracleConfig} from "silo-oracles/contracts/interfaces/IPTLinearOracleConfig.sol";

import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";
import {IPendleSYTokenLike} from "silo-oracles/contracts/pendle/interfaces/IPendleSYTokenLike.sol";
import {IPendlePTLike} from "silo-oracles/contracts/pendle/interfaces/IPendlePTLike.sol";

contract PTLinearMocks is Test {
    uint256 constant DP = 1e18;

    modifier assumeValidConfig(IPTLinearOracleFactory.DeploymentConfig memory _config) {
        _config.ptMarket = makeAddr("ptMarket");
        _config.maxYield = _config.maxYield % DP;
        _config.syRateMethod = "exchangeRate()";

        vm.assume(_config.expectedUnderlyingToken != address(0));
        vm.assume(_config.hardcodedQuoteToken != address(0));

        _;
    }

    // #########################################################
    // MOCKS ##################################################
    // #########################################################

    function _doAllNecessaryMockCalls(IPTLinearOracleFactory.DeploymentConfig memory _config) internal {
        _mockReadTokens();
        _mockReadSyRate();
        _mockAssetInfo(_config.expectedUnderlyingToken);
        _mockExpiry();
    }

    function _makeValidConfig(IPTLinearOracleFactory.DeploymentConfig memory _config) internal {
        _config.ptMarket = makeAddr("ptMarket");
        _config.maxYield = _config.maxYield % DP;
        _config.syRateMethod = "exchangeRate()";

        if (_config.expectedUnderlyingToken == address(0)) {
            _config.expectedUnderlyingToken = makeAddr("underlyingToken");
        }
        if (_config.hardcodedQuoteToken == address(0)) _config.hardcodedQuoteToken = makeAddr("quoteToken");
    }

    // #########################################################

    function _mockLatestRoundData(int256 _multiplier) internal {
        vm.mockCall(
            makeAddr("sparkLinearDiscountOracle"),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, _multiplier, 0, 0, 0)
        );
    }

    function _mockExchangeRate(uint256 _rate) internal {
        vm.mockCall(
            makeAddr("syToken"), abi.encodeWithSelector(IPendleSYTokenLike.exchangeRate.selector), abi.encode(_rate)
        );
    }

    function _mockReadTokens() internal {
        _mockReadTokens(makeAddr("syToken"), makeAddr("ptToken"), makeAddr("ptUnderlyingQuoteToken"));
    }

    function _mockReadTokens(address _syToken, address _ptToken, address _ptUnderlyingQuoteToken) internal {
        vm.mockCall(
            makeAddr("ptMarket"),
            abi.encodeWithSelector(IPendleMarketV3Like.readTokens.selector),
            abi.encode(_syToken, _ptToken, _ptUnderlyingQuoteToken)
        );
    }

    function _mockReadSyRate() internal {
        _mockReadSyRate(DP);
    }

    function _mockReadSyRate(uint256 _syRate) internal {
        vm.mockCall(
            makeAddr("syToken"), abi.encodeWithSelector(IPendleSYTokenLike.exchangeRate.selector), abi.encode(_syRate)
        );
    }

    function _mockExpiry() internal {
        _mockExpiry(makeAddr("ptToken"), block.timestamp + 1 days);
    }

    function _mockExpiry(address _ptToken, uint256 _expiry) internal {
        vm.mockCall(_ptToken, abi.encodeWithSelector(IPendlePTLike.expiry.selector), abi.encode(_expiry));
    }

    function _mockAssetInfo() internal {
        _mockAssetInfo(makeAddr("underlyingToken"));
    }

    function _mockAssetInfo(address _underlyingToken) internal {
        vm.mockCall(
            makeAddr("syToken"),
            abi.encodeWithSelector(IPendleSYTokenLike.assetInfo.selector),
            abi.encode(IPendleSYTokenLike.AssetType.TOKEN, _underlyingToken, 18)
        );
    }

    function _mockDecimals() internal {
        vm.mockCall(
            makeAddr("ptToken"), abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(18)
        );
    }
}
