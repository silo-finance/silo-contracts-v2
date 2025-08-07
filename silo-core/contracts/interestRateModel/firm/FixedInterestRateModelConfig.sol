// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModel.sol";

import {
    IFixedInterestRateModelConfig
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModelConfig.sol";

contract FixedInterestRateModelConfig is IFixedInterestRateModelConfig {
    uint256 internal immutable _APR; // solhint-disable-line var-name-mixedcase
    uint256 internal immutable _MATURITY_TIMESTAMP; // solhint-disable-line var-name-mixedcase
    address internal immutable _FIRM_VAULT; // solhint-disable-line var-name-mixedcase
    address internal immutable _SHARE_TOKEN; // solhint-disable-line var-name-mixedcase
    address internal immutable _SILO; // solhint-disable-line var-name-mixedcase

    constructor(IFixedInterestRateModel.Config memory _config) {
        _APR = _config.apr;
        _MATURITY_TIMESTAMP = _config.maturityTimestamp;
        _FIRM_VAULT = _config.firmVault;
        _SHARE_TOKEN = _config.shareToken;
        _SILO = _config.silo;
    }

    function getConfig() external view virtual returns (IFixedInterestRateModel.Config memory config) {
        config.apr = _APR;
        config.maturityTimestamp = _MATURITY_TIMESTAMP;
        config.firmVault = _FIRM_VAULT;
        config.shareToken = _SHARE_TOKEN;
        config.silo = _SILO;
    }
}
