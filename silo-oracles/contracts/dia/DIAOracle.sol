// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from  "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {OracleNormalization} from "../lib/OracleNormalization.sol";
import {DIAOracleConfig} from "./DIAOracleConfig.sol";
import {IDIAOracle} from "../interfaces/IDIAOracle.sol";
import {IDIAOracleV2} from "../external/dia/IDIAOracleV2.sol";

contract DIAOracle is ISiloOracle, IDIAOracle, Initializable {
    /// @dev price provider needs to return prices in ETH, but assets prices provided by DIA are in USD
    /// Under ETH_USD_KEY we will find ETH price in USD so we can convert price in USD into price in ETH
    string public constant ETH_USD_KEY = "ETH/USD";

    DIAOracleConfig public oracleConfig;

    /// @notice validation of config is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(DIAOracleConfig _configAddress) external virtual initializer {
        oracleConfig = _configAddress;

        IERC20Metadata baseToken = IERC20Metadata(_configAddress.getSetup().baseToken);
        // sanity check of price for 1 TOKEN
        _quote(10 ** baseToken.decimals(), address(baseToken));

        emit OracleInit(_configAddress);
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external virtual returns (uint256 quoteAmount) {
        return _quote(_baseAmount, _baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quoteView(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        return _quote(_baseAmount, _baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        IDIAOracle.DIASetup memory setup = oracleConfig.getSetup();
        return address(setup.quoteToken);
    }

    /// @param _diaOracle IDIAOracleV2 oracle where price is stored
    /// @param _key string under this key asset price will be available in DIA oracle
    /// @param _heartbeat period after which price became invalid
    /// @return assetPriceInUsd uint128 asset price
    /// @return priceUpToDate bool TRUE if price is up to date (acceptable), FALSE otherwise
    function getPriceForKey(IDIAOracleV2 _diaOracle, string memory _key, uint256 _heartbeat)
        public
        view
        virtual
        returns (uint128 assetPriceInUsd, bool priceUpToDate)
    {
        uint128 priceTimestamp;
        (assetPriceInUsd, priceTimestamp) = _diaOracle.getValue(_key);
        if (priceTimestamp == 0) revert InvalidKey();

        // price must be updated at least once every 24h, otherwise something is wrong
        uint256 oldestAcceptedPriceTimestamp;
        // block.timestamp is more than HEARTBEAT, so we can not underflow
        unchecked { oldestAcceptedPriceTimestamp = block.timestamp - _heartbeat; }

        // we not checking assetPriceInUsd != 0, because this is checked on setup, so it will be always some value here
        priceUpToDate = priceTimestamp > oldestAcceptedPriceTimestamp;
    }

    function _quote(uint256 _baseAmount, address _baseToken)
        internal
        view
        virtual
        returns (uint256 quoteAmount)
    {
        DIASetup memory data = oracleConfig.getSetup();

        if (_baseToken != data.baseToken) revert AssetNotSupported();
        if (_baseAmount > type(uint128).max) revert BaseAmountOverflow();

        (uint128 assetPriceInUsd, bool priceUpToDate) = getPriceForKey(data.diaOracle, data.key, data.heartbeat);
        if (!priceUpToDate) revert OldPrice();

        if (!data.quoteIsEth) {
            return OracleNormalization.normalizePrice(
                _baseAmount, assetPriceInUsd, data.normalizationDivider, data.normalizationMultiplier
            );
        }

        (uint128 ethPriceInUsd, bool ethPriceUpToDate) = getPriceForKey(data.diaOracle, ETH_USD_KEY, data.heartbeat);
        if (!ethPriceUpToDate) revert OldPriceEth();

        return OracleNormalization.normalizePriceEth(
            _baseAmount,
            assetPriceInUsd,
            ethPriceInUsd,
            data.normalizationDivider,
            data.normalizationMultiplier
        );
    }
}
