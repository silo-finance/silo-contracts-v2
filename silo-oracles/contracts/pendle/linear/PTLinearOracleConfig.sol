// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IPTLinearOracleConfig} from "../../interfaces/IPTLinearOracleConfig.sol";

contract PTLinearOracleConfig is IPTLinearOracleConfig {
    /// @dev Linear oracle address deploybed by ISparkLinearDiscountOracleFactory
    address internal immutable _LINEAR_ORACLE;
    /// @dev PT token address
    address internal immutable _PT_TOKEN;
    /// @dev Hardcoded quote token address that will be used for quoteToken() function in oracle
    address internal immutable _HARDCODED_QUOTE_TOKEN;
    /// @dev Normalization divider, must be 10 ** tokenDecimals of ptToken
    uint256 internal immutable _NORMALIZATION_DIVIDER;

    /// @dev all verification should be done by factory
    constructor(OracleConfig memory _cfg) {
        _LINEAR_ORACLE = _cfg.linearOracle;
        _PT_TOKEN = _cfg.ptToken;
        _HARDCODED_QUOTE_TOKEN = _cfg.hardcodedQuoteToken;
        _NORMALIZATION_DIVIDER = _cfg.normalizationDivider;
    }

    function getConfig() external view virtual returns (OracleConfig memory cfg) {
        cfg.linearOracle = _LINEAR_ORACLE;
        cfg.ptToken = _PT_TOKEN;
        cfg.hardcodedQuoteToken = _HARDCODED_QUOTE_TOKEN;
        cfg.normalizationDivider = _NORMALIZATION_DIVIDER;
    }
}
