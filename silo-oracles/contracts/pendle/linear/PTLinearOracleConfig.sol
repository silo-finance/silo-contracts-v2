// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IPTLinearOracleConfig} from "../../interfaces/IPTLinearOracleConfig.sol";

contract PTLinearOracleConfig is IPTLinearOracleConfig {
    address internal immutable _LINEAR_ORACLE;
    address internal immutable _PT_TOKEN;
    address internal immutable _HARDCODED_QUOTE_TOKEN;

    /// @dev all verification should be done by factory
    constructor(OracleConfig memory _cfg) {
        _LINEAR_ORACLE = _cfg.linearOracle;
        _PT_TOKEN = _cfg.ptToken;
        _HARDCODED_QUOTE_TOKEN = _cfg.hardcodedQuoteToken;
    }

    function getConfig() external view virtual returns (OracleConfig memory cfg) {
        cfg.linearOracle = _LINEAR_ORACLE;
        cfg.ptToken = _PT_TOKEN;
        cfg.hardcodedQuoteToken = _HARDCODED_QUOTE_TOKEN;
    }
}
