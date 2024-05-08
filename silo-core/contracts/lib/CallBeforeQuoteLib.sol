// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";

library CallBeforeQuoteLib {
    /// @dev Call `beforeQuote` on the `solvencyOracle` oracle
    /// @param _config Silo config data
    function callSolvencyOracleBeforeQuote(ISiloConfig.ConfigData memory _config) internal {
        if (_config.callBeforeQuote && _config.solvencyOracle != address(0)) {
            _callBeforeQuote(_config.solvencyOracle, _config.token);
        }
    }

    /// @dev Call `beforeQuote` on the `maxLtvOracle` oracle
    /// @param _config Silo config data
    function callMaxLtvOracleBeforeQuote(ISiloConfig.ConfigData memory _config) internal {
        if (_config.callBeforeQuote && _config.maxLtvOracle != address(0)) {
            _callBeforeQuote(_config.maxLtvOracle, _config.token);
        }
    }

    /// @dev Call `beforeQuote` on the oracle
    /// @param _oracle Oracle address
    /// @param _token Token address
    function _callBeforeQuote(address _oracle, address _token) private {
        ISiloOracle(_oracle).beforeQuote(_token);
    }
}
