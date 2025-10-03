// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";

import {IPendlePTLike} from "silo-oracles/contracts/pendle/interfaces/IPendlePTLike.sol";

contract PTLinearMocks is Test {
    uint256 constant DP = 1e18;

    modifier assumeValidConfig(IPTLinearOracleFactory.DeploymentConfig memory _config) {
        _config.ptToken = makeAddr("ptToken");
        _config.maxYield = _config.maxYield % DP;

        vm.assume(_config.hardcodedQuoteToken != address(0));

        _;
    }

    // #########################################################
    // MOCKS ##################################################
    // #########################################################

    function _doAllNecessaryMockCalls() internal {
        _mockExpiry();
    }

    function _makeValidConfig(IPTLinearOracleFactory.DeploymentConfig memory _config) internal {
        _config.ptToken = makeAddr("ptToken");
        _config.maxYield = _config.maxYield % DP;

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

    function _mockExpiry() internal {
        _mockExpiry(makeAddr("ptToken"), block.timestamp + 1 days);
    }

    function _mockExpiry(address _ptToken, uint256 _expiry) internal {
        vm.mockCall(_ptToken, abi.encodeWithSelector(IPendlePTLike.expiry.selector), abi.encode(_expiry));
    }

    function _mockDecimals() internal {
        vm.mockCall(
            makeAddr("ptToken"), abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(18)
        );
    }
}
