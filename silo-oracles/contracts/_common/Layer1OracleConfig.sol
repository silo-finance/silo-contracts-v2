// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice to keep config contract size low (this is the one that will be deployed each time)
/// factory contract take over verification. You should not deploy or use config that was not created by factory.
/// @dev This is common config for Layer1 oracles
abstract contract Layer1OracleConfig {
    /// @dev price must be updated at least once every `_HEARTBEAT` seconds, otherwise something is wrong
    uint256 internal immutable _HEARTBEAT; // solhint-disable-line var-name-mixedcase

    /// @dev constant used for normalising price
    uint256 internal immutable _DECIMALS_NORMALIZATION_DIVIDER; // solhint-disable-line var-name-mixedcase

    /// @dev constant used for normalising price
    uint256 internal immutable _DECIMALS_NORMALIZATION_MULTIPLIER; // solhint-disable-line var-name-mixedcase

    IERC20Metadata internal immutable _BASE_TOKEN; // solhint-disable-line var-name-mixedcase
    IERC20Metadata internal immutable _QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev all verification should be done by factory
    constructor(
        IERC20Metadata _baseToken,
        IERC20Metadata _quoteToken,
        uint256 _heartbeat,
        uint256 _normalizationDivider,
        uint256 _normalizationMultiplier
    ) {
        _DECIMALS_NORMALIZATION_DIVIDER = _normalizationDivider;
        _DECIMALS_NORMALIZATION_MULTIPLIER = _normalizationMultiplier;

        _BASE_TOKEN = _baseToken;
        _QUOTE_TOKEN = _quoteToken;

        _HEARTBEAT = _heartbeat;
    }
}
