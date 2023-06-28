// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "silo-core/contracts/interface/ISiloOracle.sol";
import "./interfaces/IAmmPriceModel.sol";


/// @dev annotations like (A) or (Ci) is reference to the internal document that describes model in mathematical way.
contract AmmPriceModel is IAmmPriceModel {
    /// @dev floating point 1.0
    /// @notice this has noting to do with tokens decimals, this is just precision
    uint256 constant public PRECISION = 1e18;

    /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
    uint256 public immutable K_MIN; // solhint-disable-line var-name-mixedcase

    /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
    uint256 public immutable K_MAX; // solhint-disable-line var-name-mixedcase

    /// @dev positive number, delta >= 0 and always smaller or equals T_SLOW.
    uint256 public immutable DELTA_K; // solhint-disable-line var-name-mixedcase

    /// @dev If a swap has occurred, we may assume that the current price is fair and slow down decreasing
    /// the value `k` for time Tslow, and then come back to the basic rate of decrease, if nothing happens
    /// time in seconds
    uint256 public immutable T_SLOW; // solhint-disable-line var-name-mixedcase

    /// @dev coefficient K decreases with a rate Vfast, which it is a constant.
    uint256 public immutable V_FAST; // solhint-disable-line var-name-mixedcase

    /// @dev the deceleration factor for the rate of decrease of variable k in the case of a swap, [0, 1.0]
    uint256 public immutable Q; // solhint-disable-line var-name-mixedcase

    /// @dev collateral token address => state
    mapping (address => AmmPriceState) internal _priceState;

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
        ammConfig.kMin = uint64(K_MIN);
        ammConfig.kMax = uint64(K_MAX);
        ammConfig.deltaK = uint64(DELTA_K);
        ammConfig.tSlow = uint32(T_SLOW);
        ammConfig.vFast = uint64(V_FAST);
        ammConfig.q = uint64(Q);
    }

    function getPriceState(address _collateralToken) external view returns (AmmPriceState memory) {
        return _priceState[_collateralToken];
    }

    function ammConfigVerification(AmmPriceConfig memory _config) public pure {
        // week is arbitrary value, we assume 1 week for waiting for price to go to minimum is abstract enough
        uint256 week = 7 days;

        if (_config.tSlow > week) revert INVALID_T_SLOW();
        if (!(_config.kMax != 0 && _config.kMax <= PRECISION)) revert INVALID_K_MAX();
        if (_config.kMin > _config.kMax) revert INVALID_K_MIN();
        if (_config.q > PRECISION) revert INVALID_Q();
        if (_config.vFast > PRECISION) revert INVALID_V_FAST();
        if (_config.deltaK > _config.tSlow) revert INVALID_DELTA_K();
    }

    /// @dev The initial action is adding liquidity. This method should be call on first `addLiquidity`
    function _priceInit(address _collateralToken) internal {
        if (_priceState[_collateralToken].init) {
            return;
        }

        _priceState[_collateralToken].k = uint64(K_MAX);
        _priceState[_collateralToken].lastActionTimestamp = uint64(block.timestamp);
        _priceState[_collateralToken].liquidityAdded = true;
        _priceState[_collateralToken].swap = false;
        _priceState[_collateralToken].init = true;
    }

    /// @dev Add liquidity should not change the price. But the following situation may occur.
    /// The collateral amount in the pool is very small, so the swap is not profitable even at a very low AMM price.
    /// At the same time, the AMM price continues to decrease due to a decrease in variable, and becomes inadequate.
    /// If liquidity is added at this moment, then part of the collateral will be swapped at a low price.
    /// To prevent this, we reset the values of `k` and `t`, if the previous action was either swap or withdraw, i.e.,
    /// if the previous action reduced the volume of the AMM.
    /// @param _collateralLiquidityBefore amount of collateral in the AMM before adding liquidity
    /// @param _collateralLiquidityAfter amount of collateral in the AMM after adding liquidity
    function _onAddingLiquidityPriceChange(
        address _collateralToken,
        uint256 _collateralLiquidityBefore,
        uint256 _collateralLiquidityAfter
    ) internal {
        if (_priceState[_collateralToken].liquidityAdded) {
            return;
        }

        unchecked {
            _priceState[_collateralToken].k = uint64(PRECISION
                // k can not be higher than precission because we verify that on config setup
                // also the math here will produce at most the value that is present atm, and it will not be higher
                // than PRECISION, so even with multiple calculations and subtraction we will not underflow on sub
                // TODO multiplication - check where we are mul and do the check only in once place
                - (PRECISION - _priceState[_collateralToken].k) * _collateralLiquidityBefore
                // div is safe and not 0, because we adding liquidity
                / _collateralLiquidityAfter);
        }

        _priceState[_collateralToken].liquidityAdded = true;
        _priceState[_collateralToken].swap = false;
        _priceState[_collateralToken].lastActionTimestamp = uint64(block.timestamp);
    }

    /// @param _onSwapK result of `_onSwapCalculateK()`
    function _onSwapPriceChange(address _collateralToken, uint64 _onSwapK) internal {
        _priceState[_collateralToken].k = _onSwapK;
        _priceState[_collateralToken].swap = true;
        _priceState[_collateralToken].liquidityAdded = false;
        _priceState[_collateralToken].lastActionTimestamp = uint64(block.timestamp);
    }

    /// @dev If a withdraw has occurred, the AMM price is not needed, therefore, the only change to be made is updating
    /// parameter AL. This means that on the next step we will know that the previous action reduced the volume of the
    /// AMM.
    function _onWithdrawPriceChange(address _collateralToken) internal {
        _priceState[_collateralToken].liquidityAdded = false;
    }

    /// @dev it calculates K
    /// @notice it can underflow if `_blockTimestamp` will be from past
    /// @param _blockTimestamp current (block.timestamp) time or time from future (in case for view calculations)
    function _onSwapCalculateK(address _collateralToken, uint256 _blockTimestamp) internal view returns (uint256 k) {
        unchecked {
            // unchecked: timestamp is at least lastActionTimestamp so we do not underflow in normal case
            // when we will be using block.timestamp (on swap), however, if this method will be used as view and we pass
            // time from past, we can underflow and got invalid results
            uint256 time = _blockTimestamp - _priceState[_collateralToken].lastActionTimestamp;

            if (_priceState[_collateralToken].swap) {
                if (time > T_SLOW) {
                    // unchecked: based on config verification we know that DELTA_K <= T_SLOW and `time > T_SLOW`
                    // based on that we can not underflow here
                    // we can not overflow on mul because both values are at most 64bits (<1e18)
                    time = (time - DELTA_K) * V_FAST;
                } else {
                    // unchecked: all this values are max 64bits (<1e18), so we can not produce value that will
                    // overflow because: (64bits).max * 3 < 2 ** 256
                    // unchecked: we need to div(PRECISION) because of Q, division is safe
                    time = time * Q * V_FAST / PRECISION;
                }
            } else {
                // by `* V_FAST` in each step instead of at the end, we increased precision of calculation
                // unchecked: all this values are max 64bits (<1e18), so we can not overflow
                time *= V_FAST;
            }

            // unchecked: all this values are max 64bits (<1e18), so we can not produce value that will
            // over or under flow
            k = _priceState[_collateralToken].k - time;
        }

        return k > K_MIN ? k : K_MIN;
    }
}
