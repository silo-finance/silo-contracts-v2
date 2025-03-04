// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

/// @notice PendlePTOracle is an oracle, which multiplies the underlying PT token price by PtToSyRate from Pendle.
/// This oracle must be deployed using PendlePTOracleFactory contract. PendlePTOracle decimals are equal to underlying
/// oracle's decimals. TWAP duration is constant and equal to 30 minutes. UNDERLYING_ORACLE must return the price of 
/// PT token's underlying asset. Quote token of PendlePTOracle is equal to UNDERLYING_ORACLE quote token.
contract PendlePTOracle is ISiloOracle {
    /// @dev PtToSyRate unit of measurement.
    uint256 public constant RATE_PRECISION_DECIMALS = 10 ** 18;

    /// @dev time range for TWAP to get PtToSyRate, in seconds.
    uint32 public constant TWAP_DURATION = 1800;

    /// @dev oracle to get the price of PT underlying asset.
    ISiloOracle public immutable UNDERLYING_ORACLE; // solhint-disable-line var-name-mixedcase

    /// @dev Pendle PyYtLpOracle to get PtToSyRate for a market.
    IPyYtLpOracleLike public immutable PENDLE_ORACLE; // solhint-disable-line var-name-mixedcase

    /// @dev Pendle PT token address. Quote function returns the price of this asset.
    address public immutable PT_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev PT_TOKEN underlying asset 
    address public immutable PT_UNDERLYING_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev Pendle market for PT_TOKEN. This address is used to get PtToSyRate.
    address public immutable MARKET; // solhint-disable-line var-name-mixedcase

    /// @dev This oracle's quote token is equal to UNDERLYING_ORACLE's quote token.
    address public immutable QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase

    error InvalidUnderlyingOracle();
    error PendleOracleNotReady();
    error AssetNotSupported();

    /// @dev constructor has sanity check for _underlyingOracle to not return zero or revert and for _pendleOracle to
    /// return non-zero value for _market address and TWAP_DURATION. If underlying oracle reverts, constructor will
    /// revert with original revert reason.
    constructor(
        ISiloOracle _underlyingOracle,
        IPyYtLpOracleLike _pendleOracle,
        address _ptToken,
        address _ptUnderlyingToken,
        address _market
    ) {
        (bool increaseCardinalityRequired,, bool oldestObservationSatisfied) =
            _pendleOracle.getOracleState(_market, TWAP_DURATION);
        
        require(oldestObservationSatisfied && !increaseCardinalityRequired, PendleOracleNotReady());
        require(_pendleOracle.getPtToSyRate(_market, TWAP_DURATION) != 0, PendleOracleNotReady());

        uint256 underlyingSampleToQuote = 10 ** TokenHelper.assertAndGetDecimals(_ptUnderlyingToken);
        require(_underlyingOracle.quote(underlyingSampleToQuote, _ptUnderlyingToken) != 0, InvalidUnderlyingOracle());

        UNDERLYING_ORACLE = _underlyingOracle;
        PENDLE_ORACLE = _pendleOracle;
        PT_TOKEN = _ptToken;
        PT_UNDERLYING_TOKEN = _ptUnderlyingToken;
        MARKET = _market;

        QUOTE_TOKEN = _underlyingOracle.quoteToken();
    }

    // @inheritdoc ISiloOracle
    function beforeQuote(address) external virtual {}

    // @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external virtual view returns (uint256 quoteAmount) {
        require(_baseToken == PT_TOKEN, AssetNotSupported());

        quoteAmount = UNDERLYING_ORACLE.quote(_baseAmount, PT_UNDERLYING_TOKEN);
        quoteAmount = quoteAmount * PENDLE_ORACLE.getPtToSyRate(MARKET, TWAP_DURATION) / RATE_PRECISION_DECIMALS;
    }

    // @inheritdoc ISiloOracle
    function quoteToken() external virtual view returns (address) {
        return QUOTE_TOKEN;
    }
}
