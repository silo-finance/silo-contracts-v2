// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";

library CallBeforeQuoteLib {
    /// @dev Call `beforeQuote` on the `solvencyOracle` oracle
    /// @param _config Silo config data
    function callSolvencyOracleBeforeQuote(ISiloConfig.ConfigData memory _config) internal {
        if (_config.callBeforeQuote && _config.solvencyOracle != address(0)) {
            ISiloOracle(_config.solvencyOracle).beforeQuote(_config.token);
        }
    }

    /// @dev Call `beforeQuote` on the `maxLtvOracle` oracle
    /// @param _config Silo config data
    function callMaxLtvOracleBeforeQuote(ISiloConfig.ConfigData memory _config) internal {
        if (_config.callBeforeQuote && _config.maxLtvOracle != address(0)) {
            ISiloOracle(_config.maxLtvOracle).beforeQuote(_config.token);
        }
    }
}
