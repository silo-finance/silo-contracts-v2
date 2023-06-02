// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;


/// @dev annotations like (A) or (Ci) is reference to the internal document that describes model in mathematical way.
contract AmmPriceModel {
    /// @dev we using int type for variables only because, we need to support negative values in calculations
    /// this struct is only for getter, in contract we work with constants
    /// please refer to constants description of particular variables
    struct AmmPriceConfig {
        int64 kMin;
        int64 kMax;
        int64 deltaK;
        int64 vFast;
        int32 tSlow;
        int64 q;
    }

    struct AmmPriceState {
        /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
        int64 k;

        /// @dev last time of swap or adding liquidity (tCur)
        uint64 lastActionTimestamp;

        /// @dev the indicator that the previous action was adding liquidity. (AL)
        bool liquidityAdded;

        /// @dev period of time T1 for which the price should reach the minimum reasonable value
        bool swap;
    }

    /// @dev floating point 1.0
    /// @notice this has noting to do with tokens decimals
    int256 constant public ONE = 1e18;

    uint256 constant public DECIMALS = 1e18;

    /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
    int256 public immutable K_MIN; // solhint-disable-line var-name-mixedcase

    /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
    int256 public immutable K_MAX; // solhint-disable-line var-name-mixedcase

    /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
    int256 public immutable DELTA_K; // solhint-disable-line var-name-mixedcase

    /// @dev If a swap has occurred, we may assume that the current price is fair and slow down decreasing
    /// the value `k` for time Tslow, and then come back to the basic rate of decrease, if nothing happens
    /// time in seconds
    int256 public immutable T_SLOW; // solhint-disable-line var-name-mixedcase

    /// @dev coefficient K decreases with a rate Vfast, which it is a constant.
    int256 public immutable V_FAST; // solhint-disable-line var-name-mixedcase

    /// @dev the deceleration factor for the rate of decrease of variable k in the case of a swap, [0, 1.0]
    int256 public immutable Q; // solhint-disable-line var-name-mixedcase

    AmmPriceState internal _state;

    error InvalidKmin();
    error InvalidKmax();
    error InvalidTslow();
    error InvalidQ();
    error InvalidVfast();
    error InvalidDeltaK();

    error ValueOutOfScope();
    error CastOverflow();
    error LiquidationThresholdOverflow();

    constructor(AmmPriceConfig memory _config) {
        ammConfigVerification(_config);

        K_MIN = _config.kMin;
        K_MAX = _config.kMax;
        DELTA_K = _config.deltaK;
        T_SLOW = _config.tSlow;
        V_FAST = _config.vFast;
        Q = _config.q;
    }

    function getAmmConfig() external view returns (AmmPriceConfig memory ammConfig) {
        ammConfig.kMin = int64(K_MIN);
        ammConfig.kMax = int64(K_MAX);
        ammConfig.deltaK = int64(DELTA_K);
        ammConfig.tSlow = int32(T_SLOW);
        ammConfig.vFast = int64(V_FAST);
        ammConfig.q = int64(Q);
    }

    function getState() external view returns (AmmPriceState memory) {
        return _state;
    }

    /// @dev The initial action is adding liquidity. This method should be call on first `addLiquidity`
    function init() public {
        _state.k = int64(K_MAX);
        _state.lastActionTimestamp = uint64(block.timestamp);
        _state.liquidityAdded = true;
        _state.swap = false;
    }

    /// @dev Add liquidity should not change the price. But the following situation may occur.
    /// The collateral amount in the pool is very small, so the swap is not profitable even at a very low AMM price.
    /// At the same time, the AMM price continues to decrease due to a decrease in variable, and becomes inadequate.
    /// If liquidity is added at this moment, then part of the collateral will be swaped at a low price.
    /// To prevent this, we reset the values of `k` and `t`, if the previous action was either swap or withdraw, i.e.,
    /// if the previous action reduced the volume of the AMM.
    function onAddingLiquidity() public {
        if (_state.liquidityAdded) {
            return;
        }

        _state.k = int64(K_MAX);
        _state.liquidityAdded = true;
        _state.swap = false;
        _state.lastActionTimestamp = uint64(block.timestamp);
    }

    function onSwap() public {
        int256 k;

        unchecked {
            // unchecked: timestamp is at least lastActionTimestamp so we do not underflow
            int256 time = int256(block.timestamp - _state.lastActionTimestamp);

            if (_state.swap) {
                if (time > T_SLOW) {
                    // unchecked: all this values are max 64bits, so we can not produce value that is more than 128b
                    // and it is OK to got negative number on `(time - DELTA_K)`
                    time = (time - DELTA_K) * V_FAST;
                } else {
                    // unchecked: all this values are max 64bits (<1e18), so we can not produce value that will
                    // over or under flow
                    // unchecked: we need to div(ONE) because of Q, division is safe
                    time = time * Q * V_FAST / ONE;
                }
            } else {
                // unchecked: all this values are max 64bits (<1e18), so we can not produce value that will
                // over or under flow
                time = time * V_FAST;
            }

            // unchecked: all this values are max 64bits (<1e18), so we can not produce value that will
            // over or under flow
            k = _state.k - time;
        }

        _state.k = int64(k > K_MIN ? k : K_MIN);
        _state.swap = true;
        _state.liquidityAdded = false;
        _state.lastActionTimestamp = uint64(block.timestamp);
    }

    /// @dev If a withdraw has occurred, the AMM price is not needed, therefore, the only change to be made is updating
    /// parameter AL. This means that on the next step we will know that the previous action reduced the volume of the
    /// AMM.
    function onWithdraw() public {
        _state.liquidityAdded = false;
    }

    /// @param _collateralAmount how much collateral you want to buy, amount with 18 decimals
    /// @param _collateralTwapPrice collateral price in ETH
    function collateralPrice(uint256 _collateralAmount, uint256 _collateralTwapPrice)
        public
        view
        returns (uint256 debtAmount)
    {
        uint256 value = uint64(_state.k) * _collateralTwapPrice * _collateralAmount;

        unchecked {
            // div is safe
            // div(DECIMALS) because twap price is in decimals
            // div(ONE) because of k
            return value / DECIMALS / uint256(ONE);
        }
    }

    function ammConfigVerification(AmmPriceConfig memory _config) public pure {
        // week is arbitrary value, we assume 1 week for waiting for price to go to minimum is abstract enough
        int256 week = 7 days;

        if (!(_config.tSlow >= 0 && _config.tSlow <= week)) revert InvalidTslow();
        if (!(_config.kMax > 0 && _config.kMax <= ONE)) revert InvalidKmax();
        if (!(_config.kMin >= 0 && _config.kMin <= _config.kMax)) revert InvalidKmin();
        if (!(_config.q >= 0 && _config.q <= ONE)) revert InvalidQ();
        if (!(_config.vFast >= 0 && _config.vFast <= ONE)) revert InvalidVfast();
        if (!(_config.deltaK >= 0 && _config.deltaK <= _config.tSlow)) revert InvalidDeltaK();
    }
}
