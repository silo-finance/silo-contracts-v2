// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {Initializable} from  "openzeppelin-contracts-upgradeable@v3.4.2/proxy/Initializable.sol";
import {OracleLibrary} from  "uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Pool} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISiloOracle} from "silo-core/contracts/interface/ISiloOracle.sol";
import {RevertBytes} from  "../lib/RevertBytes.sol";

contract UniswapV3Oracle is ISiloOracle, Initializable {
    using RevertBytes for bytes;

    /// @dev It is assumed that this contract will be deployed once per blockchain so blockTime can safely use
    /// immutable variable even thought it is used as implemencation contract for a proxy.
    uint8 immutable blockTime;

    /// @dev UniV3 pool address that is used for TWAP price
    IUniswapV3Pool public pool;

    /// @dev Asset for which oracle was deployed
    address public override baseToken;

    /// @dev Asset in which oracle denominates its price
    address public override quoteToken;

    /// @dev TWAP period in seconds
    uint32 public periodForAvgPrice;

    bytes32 private constant _OLD_ERROR_HASH = keccak256(abi.encodeWithSignature("Error(string)", "OLD"));

    /// @dev block time is used to estimate the average number of blocks minted in `periodForAvgPrice`
    /// block time tends to go down (not up), temporary deviations are not important
    /// Ethereum's block time is almost never higher than ~15 sec, so in practice we shouldn't need to set it above that
    /// 60 was chosen as an arbitrary maximum just to prevent human errors
    uint256 public constant MAX_ACCEPTED_BLOCK_TIME = 60;

    /// @notice Emitted when TWAP period changes
    /// @param pool UniswapV3 pool address
    /// @param baseToken asset address that is going to be quoted (priced)
    /// @param quoteToken asset address in which quotes are given
    /// @param periodForAvgPrice TWAP period in seconds, ie. 1800 means 30 min
    event OracleInit(IUniswapV3Pool pool, address baseToken, address quoteToken, uint32 periodForAvgPrice);

    /// @param _blockTime estimated block time, it is better to set it bit lower than higher that avg block time
    /// eg. if ETH block time is 13~13.5s, you can set it to 12s
    constructor(uint8 _blockTime) {
        blockTime = _blockTime;
    }

    /// @param _pool UniswapV3 pool address used for TWAP
    /// @param _baseToken asset address that is going to be quoted (priced)
    /// @param _periodForAvgPrice period in seconds for TWAP price, ie. 1800 means 30 min
    function initialize(IUniswapV3Pool _pool, address _baseToken, uint32 _periodForAvgPrice) external initializer {
        pool = _pool;
        baseToken = _baseToken;
        periodForAvgPrice = _periodForAvgPrice;
        quoteToken = _baseToken == _pool.token0() ? _pool.token1() : _pool.token0();

        emit OracleInit(_pool, _baseToken, quoteToken, _periodForAvgPrice);

        verifyPool(address(_pool), _baseToken, quoteToken, _periodForAvgPrice, blockTime);
    }

    /// @notice Adjust UniV3 pool cardinality to Silo's requirements.
    /// Call `observationsStatus` to see, if you need to execute this method.
    /// This method prepares pool for setup for price provider. In order to run `setupAsset` for asset,
    /// pool must have buffer to provide TWAP price. By calling this adjustment (and waiting necessary amount of time)
    /// pool will be ready for setup. It will collect valid number of observations, so the pool can be used
    /// once price data is ready.
    /// @dev Increases observation cardinality for univ3 oracle pool if needed, see getPrice desc for details.
    /// We should call it on init and when we are changing the pool (univ3 can have multiple pools for the same tokens)
    function adjustOracleCardinality() external virtual {
        // ideally we want to have data at every block during periodForAvgPrice
        // If we want to get TWAP for 5 minutes and assuming we have tx in every block, and block time is 15 sec,
        // then for 5 minutes we will have 20 blocks, that means our requiredCardinality is 20.
        uint256 requiredCardinality = periodForAvgPrice / blockTime;

        (,,,, uint16 cardinalityNext,,) = pool.slot0();
        if (cardinalityNext >= requiredCardinality) revert("NotNecessary");

        // initialize required amount of slots, it will cost!
        pool.increaseObservationCardinalityNext(uint16(requiredCardinality));
    }

    function oldestTimestamp() external view virtual returns (uint32 oldestTimestamps) {
        (,, uint16 observationIndex, uint16 currentObservationCardinality,,,) = pool.slot0();
        oldestTimestamps = resolveOldestObservationTimestamp(pool, observationIndex, currentObservationCardinality);
    }

    /// @notice Check if UniV3 pool has enough cardinality to meet Silo's requirements
    /// If it does not have, please execute `adjustOracleCardinality`.
    /// @return bufferFull TRUE if buffer is ready to provide TWAP price rof required period
    /// @return enoughObservations TRUE if buffer has enough observations spots (they don't have to be filled up yet)
    /// @return currentCardinality cardinality of configured UniV3 pool
    function observationsStatus()
        public
        view
        virtual
        returns (bool bufferFull, bool enoughObservations, uint16 currentCardinality)
    {
        (,,, uint16 currentObservationCardinality, uint16 observationCardinalityNext,,) = pool.slot0();

        // ideally we want to have data at every block during periodForAvgPrice
        uint256 requiredCardinality = periodForAvgPrice / blockTime;

        bufferFull = currentObservationCardinality >= requiredCardinality;
        enoughObservations = observationCardinalityNext >= requiredCardinality;
        currentCardinality = currentObservationCardinality;
    }

    /// @dev It verifies, if provider pool for asset (and quote token) is valid.
    /// Throws when there is no pool or pool is empty (zero liquidity) or not ready for price
    /// @param _pool UniV3 pool address
    /// @param _baseToken asset for which prices are going to be calculated
    /// @param _quoteToken asset in which prices are going to be denominated
    /// @param _periodForAvgPrice time for TWAP configuration
    /// @param _blockTime block time for the blockchain that this contract is deployed on
    /// @return true if verification successful, otherwise throws
    function verifyPool(
        address _pool,
        address _baseToken,
        address _quoteToken,
        uint32 _periodForAvgPrice,
        uint8 _blockTime
    ) public view virtual returns (bool) {
        uint256 requiredCardinality = _periodForAvgPrice / _blockTime;
        if (requiredCardinality > type(uint16).max) revert("InvalidRequiredCardinality");
        if (_periodForAvgPrice == 0) revert("InvalidPeriodForAvgPrice");
        if (blockTime == 0 || blockTime >= MAX_ACCEPTED_BLOCK_TIME) revert("InvalidBlockTime");
        if (_pool == address(0) || _baseToken == address(0) || _quoteToken == address(0)) revert("ZeroAddress");
        return true;
    }

    /// @dev UniV3 saves price only on: mint, burn and swap.
    /// Mint and burn will write observation only when "current tick is inside the passed range" of ticks.
    /// I think that means, that if we minting/burning outside ticks range  (so outside current price)
    /// it will not modify observation. So we left with swap.
    ///
    /// Swap will write observation under this condition:
    ///     // update tick and write an oracle entry if the tick change
    ///     if (state.tick != slot0Start.tick) {
    /// that means, it is possible that price will be up to date (in a range of same tick)
    /// but observation timestamp will be old.
    ///
    /// Every pool by default comes with just one slot for observation (cardinality == 1).
    /// We can increase number of slots so TWAP price will be "better".
    /// When we increase, we have to wait until new tx will write new observation.
    /// Based on all above, we can tell how old is observation, but this does not mean the price is wrong.
    /// UniV3 recommends to use `observe` and `OracleLibrary.consult` uses it.
    /// `observe` reverts if `secondsAgo` > oldest observation, means, if there is any price observation in selected
    /// time frame, it will revert. Otherwise it will return either exact TWAP price or by interpolation.
    ///
    /// Conclusion: we can choose how many observation pool will be storing, but we need to remember,
    /// not all of them might be used to provide our price. Final question is: how many observations we need?
    ///
    /// How UniV3 calculates TWAP
    /// we ask for TWAP on time range ago:now using `OracleLibrary.consult`, it is all about find the right tick
    /// - we call `IUniswapV3Pool(pool).observe(secondAgo)` that returns two accumulator values (for ago and now)
    /// - each observation is resolved by `observeSingle`
    ///   - for _now_ we just using latest observation, and if it does not match timestamp, we interpolate (!)
    ///     and this is how we got the _tickCumulative_, so in extreme situation, if last observation was made day ago,
    ///     UniV3 will interpolate to reflect _tickCumulative_ at current time
    ///   - for _ago_ we search for observation using `getSurroundingObservations` that give us
    ///     before and after observation, base on which we calculate "avg" and we have target _tickCumulative_
    ///     - getSurroundingObservations: it's job is to find 2 observations based on which we calculate tickCumulative
    ///       here is where all calculations can revert, if ago < oldest observation, otherwise it will be calculated
    ///       either by interpolation or we will have exact match
    /// - now with both _tickCumulative_s we calculating TWAP
    ///
    /// recommended observations are = 30 min / blockTime
    /// @inheritdoc ISiloOracle
    /// @dev Returns quote price for _baseAmount of _baseToken
    /// @param _baseAmount Amount of priced token
    /// @param _baseToken Address of priced token
    function quote(uint256 _baseAmount, address _baseToken) external virtual override returns (uint256 quoteAmount) {
        quoteAmount = _quoteInternal(_baseAmount, _baseToken);
    }

    function quoteView(uint256 _baseAmount, address _baseToken) external view virtual override returns (uint256 quoteAmount) {
        quoteAmount = _quoteInternal(_baseAmount, _baseToken);
    }

    function _quoteInternal(uint256 _baseAmount, address _baseToken) internal view virtual returns (uint256 quoteAmount) {
        if (_baseAmount > type(uint128).max) revert("Overflow");
        uint128 _baseAmount128 = uint128(_baseAmount);
        int24 timeWeightedAverageTick = _consult(pool);
        quoteAmount = OracleLibrary.getQuoteAtTick(timeWeightedAverageTick, _baseAmount128, _baseToken, quoteToken);
    }

    /// @param _pool uniswap V3 pool address
    /// @param _currentObservationIndex the most-recently updated index of the observations array
    /// @param _currentObservationCardinality the current maximum number of observations that are being stored
    /// @return lastObservationTimestamp last observation timestamp
    function resolveOldestObservationTimestamp(
        IUniswapV3Pool _pool,
        uint16 _currentObservationIndex,
        uint16 _currentObservationCardinality
    )
        public
        view
        virtual
        returns (uint32 lastObservationTimestamp)
    {
        bool initialized;

        (
            lastObservationTimestamp,,,
            initialized
        ) = _pool.observations((_currentObservationIndex + 1) % _currentObservationCardinality);

        // if not initialized, we just check id#0 as this will be the oldest
        if (!initialized) {
            (lastObservationTimestamp,,,) = _pool.observations(0);
        }
    }

    /// @notice Fetches time-weighted average tick using Uniswap V3 oracle
    /// @dev this is based on `OracleLibrary.consult`, we adjusted it to handle `OLD` error, time window will adjust
    /// to available pool observations
    /// @param _pool Address of Uniswap V3 pool that we want to observe
    /// @return timeWeightedAverageTick time-weighted average tick from (block.timestamp - period) to block.timestamp
    function _consult(IUniswapV3Pool _pool) internal view virtual returns (int24 timeWeightedAverageTick) {
        (uint32 period, int56[] memory tickCumulatives) = _calculatePeriodAndTicks(_pool);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        timeWeightedAverageTick = int24(tickCumulativesDelta / period);

        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % period != 0)) timeWeightedAverageTick--;
    }

    /// @param _pool Address of Uniswap V3 pool
    /// @return period Number of seconds in the past to start calculating time-weighted average
    /// @return tickCumulatives Cumulative tick values as of each secondsAgos from the current block timestamp
    function _calculatePeriodAndTicks(IUniswapV3Pool _pool)
        internal
        view
        virtual
        returns (uint32 period, int56[] memory tickCumulatives)
    {
        period = periodForAvgPrice;
        bool old;

        (tickCumulatives, old) = _observe(_pool, period);

        if (old) {
            (,, uint16 observationIndex, uint16 currentObservationCardinality,,,) = _pool.slot0();

            uint32 latestTimestamp =
                resolveOldestObservationTimestamp(_pool, observationIndex, currentObservationCardinality);

            period = uint32(block.timestamp - latestTimestamp);

            (tickCumulatives, old) = _observe(_pool, period);
            if (old) revert("STILL OLD");
        }
    }

    /// @param _pool UniV3 pool address
    /// @param _period Number of seconds in the past to start calculating time-weighted average
    function _observe(IUniswapV3Pool _pool, uint32 _period)
        internal
        view
        virtual
        returns (int56[] memory tickCumulatives, bool old)
    {
        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = _period;
        // secondAgos[1] = 0; // default is 0

        try _pool.observe(secondAgos)
            returns (int56[] memory ticks, uint160[] memory)
        {
            tickCumulatives = ticks;
            old = false;
        }
        catch (bytes memory reason) {
            if (keccak256(reason) != _OLD_ERROR_HASH) reason.revertBytes("_observe");
            old = true;
        }
    }
}
