// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPendleOracleHelper} from "silo-oracles/contracts/pendle/interfaces/IPendleOracleHelper.sol";
import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {IPendleSYTokenLike} from "silo-oracles/contracts/pendle/interfaces/IPendleSYTokenLike.sol";

/// @notice PendleLPTOracle is an oracle, which multiplies the underlying LP token price by getLpToSyRate from Pendle.
/// This oracle must be deployed using PendleLPTOracleFactory contract. PendleLPTOracle decimals are equal to underlying
/// oracle's decimals. TWAP duration is constant and equal to 30 minutes. UNDERLYING_ORACLE must return the price of 
/// LP token's underlying asset. Quote token of PendleLPTOracle is equal to UNDERLYING_ORACLE quote token.
contract PendleLPTOracle is ISiloOracle {
    /// @dev getLpToSyRate unit of measurement.
    uint256 public constant PENDLE_RATE_PRECISION = 10 ** 18;

    /// @dev time range for TWAP to get getLpToSyRate, in seconds.
    uint32 public constant TWAP_DURATION = 30 minutes;

    /// @dev Pendle oracle helper to get getLpToSyRate for a market.
    /// It was deployed to have the same address for all networks.
    /// https://docs.pendle.finance/Developers/Oracles/HowToIntegratePtAndLpOracle
    IPendleOracleHelper public constant PENDLE_ORACLE =
        IPendleOracleHelper(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    /// @dev oracle to get the price of PT underlying asset.
    ISiloOracle public immutable UNDERLYING_ORACLE; // solhint-disable-line var-name-mixedcase

    /// @dev LP_TOKEN underlying asset 
    address public immutable LP_UNDERLYING_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev Pendle market. This address is used to get getLpToSyRate.
    address public immutable MARKET; // solhint-disable-line var-name-mixedcase

    /// @dev This oracle's quote token is equal to UNDERLYING_ORACLE's quote token.
    address public immutable QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase

    error TokensDecimalsDoesNotMatch();
    error InvalidUnderlyingOracle();
    error PendleOracleNotReady();
    error PendleGetLpToSyRateIsZero();
    error AssetNotSupported();
    error ZeroPrice();

    /// @dev constructor has sanity check for _underlyingOracle to not return zero or revert and for _pendleOracle to
    /// return non-zero value for _market address and TWAP_DURATION. If underlying oracle reverts, constructor will
    /// revert with original revert reason.
    constructor(ISiloOracle _underlyingOracle, address _market) {
        address lpUnderlyingToken = getLpUnderlyingToken(_market);
        uint256 lpUnderlyingTokenDecimals = TokenHelper.assertAndGetDecimals(lpUnderlyingToken);

        require(lpUnderlyingTokenDecimals == TokenHelper.assertAndGetDecimals(lpUnderlyingToken), TokensDecimalsDoesNotMatch());

        (bool increaseCardinalityRequired,, bool oldestObservationSatisfied) =
            PENDLE_ORACLE.getOracleState(_market, TWAP_DURATION);
        
        require(oldestObservationSatisfied && !increaseCardinalityRequired, PendleOracleNotReady());
        require(PENDLE_ORACLE.getLpToSyRate(_market, TWAP_DURATION) != 0, PendleGetLpToSyRateIsZero());

        uint256 underlyingSampleToQuote = 10 ** lpUnderlyingTokenDecimals;
        require(_underlyingOracle.quote(underlyingSampleToQuote, lpUnderlyingToken) != 0, InvalidUnderlyingOracle());

        UNDERLYING_ORACLE = _underlyingOracle;
        LP_UNDERLYING_TOKEN = lpUnderlyingToken;
        MARKET = _market;

        QUOTE_TOKEN = _underlyingOracle.quoteToken();
    }

    // @inheritdoc ISiloOracle
    function beforeQuote(address) external virtual {}

    // @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external virtual view returns (uint256 quoteAmount) {
        require(_baseToken == LP_UNDERLYING_TOKEN, AssetNotSupported());

        quoteAmount = UNDERLYING_ORACLE.quote(_baseAmount, LP_UNDERLYING_TOKEN);
        quoteAmount = quoteAmount * PENDLE_ORACLE.getLpToSyRate(MARKET, TWAP_DURATION) / PENDLE_RATE_PRECISION;

        require(quoteAmount != 0, ZeroPrice());
    }

    // @inheritdoc ISiloOracle
    function quoteToken() external virtual view returns (address) {
        return QUOTE_TOKEN;
    }

    function getLpUnderlyingToken(address _market) public virtual view returns (address lpUnderlyingToken) {
        (address syToken,,) = IPendleMarketV3Like(_market).readTokens();
        lpUnderlyingToken = IPendleSYTokenLike(syToken).yieldToken();
    }
}
