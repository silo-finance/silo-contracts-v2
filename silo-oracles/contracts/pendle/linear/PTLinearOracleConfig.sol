// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IPTLinearOracleConfig} from "../../interfaces/IPTLinearOracleConfig.sol";

contract PTLinearOracleConfig is IPTLinearOracleConfig {
    address internal immutable _LINEAR_ORACLE;
    address internal immutable _PT_TOKEN;
    address internal immutable _SY_TOKEN;
    address internal immutable _EXPECTED_UNDERLYING_TOKEN;
    address internal immutable _HARDCODED_QUOTE_TOKEN;
    bytes4 internal immutable _SY_RATE_METHOD_SELECTOR;

    /// @dev all verification should be done by factory
    constructor(OracleConfig memory _cfg) {
        require(_cfg.linearOracle != address(0), LinearOracleCannotBeZero());

        _LINEAR_ORACLE = _cfg.linearOracle;
        _PT_TOKEN = _cfg.ptToken;
        _SY_TOKEN = _cfg.syToken;
        _EXPECTED_UNDERLYING_TOKEN = _cfg.expectedUnderlyingToken;
        _HARDCODED_QUOTE_TOKEN = _cfg.hardcodedQuoteToken;
        _SY_RATE_METHOD_SELECTOR = _cfg.syRateMethodSelector;
    }

    function getConfig() external view virtual returns (OracleConfig memory cfg) {
        cfg.linearOracle = _LINEAR_ORACLE;
        cfg.ptToken = _PT_TOKEN;
        cfg.syToken = _SY_TOKEN;
        cfg.expectedUnderlyingToken = _EXPECTED_UNDERLYING_TOKEN;
        cfg.hardcodedQuoteToken = _HARDCODED_QUOTE_TOKEN;
        cfg.syRateMethodSelector = _SY_RATE_METHOD_SELECTOR;
    }
}
