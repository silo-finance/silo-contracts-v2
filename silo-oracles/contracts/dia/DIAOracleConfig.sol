// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {IDIAOracle} from "../interfaces/IDIAOracle.sol";
import {IDIAOracleV2} from "../external/dia/IDIAOracleV2.sol";
import {Layer1OracleConfig} from "../_common/Layer1OracleConfig.sol";

/// @notice to keep config contract size low (this is the one that will be deployed each time)
/// factory contract take over verification. You should not deploy or use config that was not created by factory.
contract DIAOracleConfig is Layer1OracleConfig {
    /// @dev Oracle deployed for Silo by DIA, all our prices will be submitted to this contract
    IDIAOracleV2 internal immutable _DIA_ORACLEV2; // solhint-disable-line var-name-mixedcase

    /// @dev price from /USD can be converted to /ETH if DIA has ETH/USD feed. In that case this flag will be true.
    bool internal immutable _QUOTE_IS_ETH; // solhint-disable-line var-name-mixedcase

    /// @dev we accessing prices for assets by keys eg. "Jones/USD"
    /// I tried to store it as bytes32 immutable, but translation to string uses over 5K gas, storage string is less
    /// @notice this is actually a string stored as bytes32, so we can make it immutable
    string internal _diaKey;

    /// @dev all verification should be done by factory
    constructor(
        IDIAOracle.DIAConfig memory _config,
        bool _quoteIsEth,
        uint256 _normalizationDivider,
        uint256 _normalizationMultiplier,
        string memory _key
    )
        Layer1OracleConfig(
            _config.baseToken,
            _config.quoteToken,
            _config.heartbeat,
            _normalizationDivider,
            _normalizationMultiplier
        )
    {
        _diaKey = _key;
        _DIA_ORACLEV2 = _config.diaOracle;
        _QUOTE_IS_ETH = _quoteIsEth;
    }

    function getSetup() external view virtual returns (IDIAOracle.DIASetup memory setup) {
        setup.diaOracle = _DIA_ORACLEV2;
        setup.baseToken = address(_BASE_TOKEN);
        setup.quoteToken = address(_QUOTE_TOKEN);
        setup.heartbeat = uint32(_HEARTBEAT);
        setup.normalizationDivider = _DECIMALS_NORMALIZATION_DIVIDER;
        setup.normalizationMultiplier = _DECIMALS_NORMALIZATION_MULTIPLIER;
        setup.quoteIsEth = _QUOTE_IS_ETH;
        setup.key = _diaKey;
    }
}
