// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPTLinearOracleConfig} from "../../interfaces/IPTLinearOracleConfig.sol";
import {IPTLinearOracle} from "../../interfaces/IPTLinearOracle.sol";

/*
TODO:
- add chainlink interface, so we can use in input to other oracles
*/
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

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
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

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData() external 
        view 
        virtual 
        override 
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        // TODO: implement for 1.0 base token
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        return oracleConfig.getConfig().hardcodedQuoteToken;
    }

    /// @inheritdoc IPTLinearOracle
    function multiplier() external view virtual returns (int256 ptMultiplier) {
        (, ptMultiplier,,,) = AggregatorV3Interface(oracleConfig.getConfig().linearOracle).latestRoundData();
    }

    /// @inheritdoc ISiloOracle
    function beforeQuote(address) external pure virtual override {
        // nothing to execute
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
