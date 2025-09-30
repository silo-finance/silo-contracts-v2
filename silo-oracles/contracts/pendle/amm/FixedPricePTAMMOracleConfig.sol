// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IPendleAMM} from "../../interfaces/IPendleAMM.sol";
import {IFixedPricePTAMMOracleConfig} from "../../interfaces/IFixedPricePTAMMOracleConfig.sol";

contract FixedPricePTAMMOracleConfig is IFixedPricePTAMMOracleConfig {
    IPendleAMM internal immutable _PENDLE_AMM; // solhint-disable-line var-name-mixedcase
    address internal immutable _BASE_TOKEN; // solhint-disable-line var-name-mixedcase
    address internal immutable _QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase
    address internal immutable _HARDCODED_QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev all verification should be done by factory
    constructor(DeploymentConfig memory _cfg) {
        _PENDLE_AMM = _cfg.amm;
        _BASE_TOKEN = _cfg.ptToken;
        _QUOTE_TOKEN = _cfg.ptUnderlyingQuoteToken;
        _HARDCODED_QUOTE_TOKEN = _cfg.hardcoddedQuoteToken;
    }

    function getConfig() external view virtual returns (DeploymentConfig memory cfg) {
        cfg.amm = _PENDLE_AMM;
        cfg.ptToken = _BASE_TOKEN;
        cfg.ptUnderlyingQuoteToken = _QUOTE_TOKEN;
        cfg.hardcoddedQuoteToken = _HARDCODED_QUOTE_TOKEN;
    }
}
