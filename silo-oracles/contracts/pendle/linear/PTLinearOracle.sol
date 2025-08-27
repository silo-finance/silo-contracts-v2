// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPTLinearOracleConfig} from "../../interfaces/IPTLinearOracleConfig.sol";
import {IPTLinearOracle} from "../../interfaces/IPTLinearOracle.sol";

contract PTLinearOracle is IPTLinearOracle, Initializable, AggregatorV3Interface {
    uint256 internal constant _DP = 1e18;

    IPTLinearOracleConfig public oracleConfig;

    /// @inheritdoc IPTLinearOracle
    string public syRateMethod;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IPTLinearOracle
    function initialize(IPTLinearOracleConfig _configAddress, string memory _syRateMethod)
        external
        virtual
        initializer
    {
        require(address(_configAddress) != address(0), EmptyConfigAddress());

        oracleConfig = _configAddress;
        syRateMethod = _syRateMethod;

        emit PTLinearOracleInitialized(_configAddress);
    }

    /// @inheritdoc AggregatorV3Interface
    /// @notice because this is just a proxy to interface, only answer will have non zero value
    /// return value is in 18 decimals, not 8 like in chainlink
    function latestRoundData() 
        external 
        view 
        virtual 
        override 
        returns (uint80, int256 answer, uint256, uint256, uint80) 
    {
        address baseToken = oracleConfig.getConfig().ptToken;
        uint256 baseAmount = 10 ** TokenHelper.assertAndGetDecimals(baseToken);

        answer = SafeCast.toInt256(quote(baseAmount, baseToken));
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        return oracleConfig.getConfig().hardcodedQuoteToken;
    }

    /// @inheritdoc IPTLinearOracle
    function multiplier() external view virtual returns (int256 ptMultiplier) {
        (, ptMultiplier,,,) = AggregatorV3Interface(oracleConfig.getConfig().linearOracle).latestRoundData();
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external view returns (string memory) {
        string memory baseSymbol = TokenHelper.symbol(oracleConfig.getConfig().ptToken);
        string memory quoteSymbol = TokenHelper.symbol(oracleConfig.getConfig().hardcodedQuoteToken);
        return string.concat("PTLinearOracle for ", baseSymbol, " / ", quoteSymbol);
    }

    /// @inheritdoc ISiloOracle
    function beforeQuote(address) external pure virtual override {
        // nothing to execute
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external pure returns (uint256) {
        return 1;
    }

    /// @notice not in use, always returns 0s, use latestRoundData instead
    function getRoundData(uint80 /* _roundId */) external pure returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, 0, 0, 0, 0);
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) public view virtual returns (uint256 quoteAmount) {
        IPTLinearOracleConfig oracleCfg = oracleConfig;
        require(address(oracleCfg) != address(0), NotInitialized());

        IPTLinearOracleConfig.OracleConfig memory cfg = oracleCfg.getConfig();

        require(_baseToken == cfg.ptToken, AssetNotSupported());
        require(_baseAmount <= type(uint128).max, BaseAmountOverflow());

        (, int256 ptMultiplier,,,) = AggregatorV3Interface(cfg.linearOracle).latestRoundData();

        uint256 exchangeFactor = callForExchangeFactor(cfg.syToken, cfg.syRateMethodSelector);

        quoteAmount = _baseAmount * exchangeFactor * uint256(ptMultiplier) / _DP / _DP;

        require(quoteAmount != 0, ZeroQuote());
    }

    /// @inheritdoc IPTLinearOracle
    function callForExchangeFactor(address _syToken, bytes4 _syRateMethodSelector)
        public
        view
        virtual
        returns (uint256 exchangeFactor)
    {
        (bool success, bytes memory data) = _syToken.staticcall(abi.encodeWithSelector(_syRateMethodSelector));
        require(success && data.length != 0, FailedToCallSyRateMethod());

        exchangeFactor = abi.decode(data, (uint256));
        require(exchangeFactor != 0, InvalidExchangeFactor());
    }
}
