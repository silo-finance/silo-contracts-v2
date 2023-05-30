// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/console.sol";

/// @notice DRAFT
/// @dev annotations like (A) or (Ci) is reference to the internal document that describes model in mathematical way.
contract AmmStateModel {
    /// TODO not sure, if this exponential model is really useful, need to verify in QA
    /// @dev share = m * 2^e;
    struct Share {
        uint112 m;
        uint112 e;
    }

    struct TotalState {
        /// @dev the total amount of collateral historically provided (denominated in collateral tokens) (A)
        uint256 collateralAmount;

        /// @dev the total liquidation-time value of collateral (V)
        uint256 liquidationTimeValue;

        /// @dev the total number of shares (S)
        uint256 shares;

        /// @dev the total amount of remaining (not yet swapped) collateral in the pool (C)
        uint256 availableCollateral;

        /// @dev the total amount of debt token in the pool (D)
        uint256 debtAmount;

        /// @dev an auxiliary variable, explained in the internal documentation (R)
        uint256 R; // solhint-disable-line var-name-mixedcase
    }

    struct UserPosition {
        /// @dev amount of collateral historically provided by the user (denominated in collateral tokens) (Ai)
        uint256 collateralAmount;

        /// @dev liquidation-time value of collateral provided by the user (Vi)
        uint256 liquidationTimeValue;

        /// @dev number of shares held by the user (Si)
        uint256 shares;
    }

    /// @dev 100%
    uint256 constant public ONE = 1e18;

    /// @dev
    uint256 constant public DECIMALS = 1e18;

    // TODO we will need two total states for two flows tokenA -> tokenB, tokenB -> tokenA
    TotalState private _totalState;

    // TODO we will need two states for each user, same as above
    mapping (address => UserPosition) private _positions;

    error UserNotCleanedUp();
    error PercentOverflow();
    error NotEnoughAvailableCollateral();

    function getTotalState() external view returns (TotalState memory) {
        return _totalState;
    }

    function positions(address _user) external view returns (UserPosition memory) {
        return _positions[_user];
    }

    /// @notice endpoint for liquidation, here borrower collateral is added as liquidity
    /// @dev User adds `dC` units of collateral to the pool and receives shares.
    /// Liquidation-time value of the collateral at the current spot price P(t) is added to the user’s count.
    /// The variable R is updated so that it keeps track of the sum of Ri
    /// @param _user depositor, owner of position
    /// @param _collateralPrice current price P(T) of collateral, in 18 decimals
    function addLiquidity(
        address _user,
        uint256 _collateralPrice,
        uint256 _collateralAmount
    ) public returns (uint256 shares) {
        UserPosition storage position = _positions[_user];

        if (position.shares != 0) revert UserNotCleanedUp();

        // div(DECIMALS) because price is expected to be in 18 decimals
        uint256 dV = _collateralPrice * _collateralAmount / DECIMALS;

        // TBD: shares transformation to/from exponential
        shares = _totalState.availableCollateral == 0
            ? _collateralAmount
            : _collateralAmount * _totalState.shares / _totalState.availableCollateral;

        // because of cleanup, there will no previous state, so this is all user initial values
        position.collateralAmount = _collateralAmount; // Ai + dC, but Ai is 0
        position.liquidationTimeValue = dV; // Vi + dV, but Vi is 0
        position.shares = shares;

        // TODO check usage of A (collateralAmount) and C (availableCollateral) !!! everywhere
        _totalState.collateralAmount += _collateralAmount;
        _totalState.liquidationTimeValue += dV;
        _totalState.shares += shares;
        _totalState.availableCollateral += _collateralAmount;

        // now let's calculate R
        // if Ci, Vi, Ai, Ri = 0 (because of cleanup), then we end up with R = R + (dC*dV/dC) = R + dV
        _totalState.R += dV;
    }

    /// @dev state change on swap
    function onSwap(
        uint256 _collateralOut,
        uint256 _debtIn
    ) public {
        if (_collateralOut > _totalState.availableCollateral) revert NotEnoughAvailableCollateral();

         unchecked {
            // R should be scaled before other changes
            _totalState.R = _totalState.R * (_totalState.availableCollateral - _collateralOut) / _totalState.availableCollateral;

            _totalState.availableCollateral -= _collateralOut;
            _totalState.debtAmount += _debtIn;
         }
    }

    /// @param _user owner of position
    /// @param _w fraction of user position that needs to be withdrawn, 0 < _w <= 100%
    /// @return debtAmount
    function withdrawLiquidity(
        address _user,
        uint256 _w
    ) public returns (uint256 debtAmount) {
        if (_w > ONE) revert PercentOverflow();

        UserPosition storage position = _positions[_user];

        uint256 ci = getCurrentlyAvailableCollateralForUser(
            _totalState.shares,
            _totalState.availableCollateral,
            position.shares
        );

        uint256 dC = _w * ci / ONE;

        uint256 dD = _w * userAvailableDebtAmount(
            _totalState.debtAmount,
            _totalState.liquidationTimeValue,
            _totalState.R,
            position,
            ci
        ) / ONE;

        uint256 dA = _w * position.collateralAmount / ONE;
        uint256 dV = _w * position.liquidationTimeValue / ONE;
        uint256 dS = _w * position.shares / ONE; // TODO support exponential

        // TODO in tests we will have to make sure, that when one of below subtraction end up being zero,
        //  others should be zeros as well

        // now let's calculate R, it must be done before other state is updated
        uint256 ri = auxiliaryVariableRi(ci, position.liquidationTimeValue, position.collateralAmount);

        uint256 newCollateralAmount = position.collateralAmount - dA;
        uint256 newLiquidationTimeValue = position.liquidationTimeValue - dV;

        uint256 riNew = newCollateralAmount == 0
            ? 0
            : (ci - dC) * newLiquidationTimeValue / newCollateralAmount;

        _totalState.R = _totalState.R - ri + riNew;

        position.collateralAmount = newCollateralAmount;
        position.liquidationTimeValue = newLiquidationTimeValue;
        position.shares -= dS;

        _totalState.collateralAmount -= dA;
        _totalState.liquidationTimeValue -= dV;
        _totalState.shares -= dS;
        _totalState.availableCollateral -= dC;
        _totalState.debtAmount -= dD;

        return dD;
    }

    /// @notice The part of the user’s collateral amount that has already been swapped
    function userSwappedCollateral(address _user) public view returns (uint256 swappedCollateralFraction) {
        UserPosition memory position = _positions[_user];

        uint256 userAvailableCollateralAmount = getCurrentlyAvailableCollateralForUser(
            _totalState.shares,
            _totalState.availableCollateral,
            position.shares
        );

        swappedCollateralFraction =
            (position.collateralAmount - userAvailableCollateralAmount) / position.collateralAmount;
    }

    /// @dev amount of collateral currently available to user
    /// @param _totalShares the total number of shares (S)
    /// @param _totalAvailableCollateral the total amount of remaining (not yet swapped) collateral in the pool (C)
    /// @param _userShares number of shares held by the user (Si)
    /// @return amount amount of collateral currently available to user (Ci)
    function getCurrentlyAvailableCollateralForUser(
        uint256 _totalShares,
        uint256 _totalAvailableCollateral,
        uint256 _userShares
    ) public pure returns (uint256 amount) {
        return _totalShares == 0 || _userShares == 0 ? 0 : _userShares * _totalAvailableCollateral / _totalShares;
    }

    /// @dev amount of debt token currently available to user
    /// Its part in the total amount of available debt token.
    /// @param _totalDebtAmount the total amount of debt token in the pool (D)
    /// @param _totalLiquidationTimeValue the total liquidation-time value of collateral in the pool (V)
    /// @param _totalR auxiliary variable R
    /// @param _position UserPosition
    /// @param _userAvailableCollateralAmount amount of collateral currently available to user (Ci)
    /// @return amount of debt token currently available to user (Di)
    function userAvailableDebtAmount(
        uint256 _totalDebtAmount,
        uint256 _totalLiquidationTimeValue,
        uint256 _totalR,
        UserPosition memory _position,
        uint256 _userAvailableCollateralAmount
    ) public pure returns (uint256 amount) {
        uint256 ri = auxiliaryVariableRi(
            _userAvailableCollateralAmount,
            _position.liquidationTimeValue,
            _position.collateralAmount
        );

        uint256 divider = _totalLiquidationTimeValue - _totalR;

        return divider == 0 ? 0 : (_position.liquidationTimeValue - ri) * _totalDebtAmount / divider;
    }

    /// @param _userAvailableCollateralAmount amount of collateral currently available to user (Ci)
    /// @param _userLiquidationTimeValue liquidation-time value of collateral provided by the user (Vi)
    /// @param _userCollateralAmount amount of collateral historically provided by the user
    /// (denominated in collateral tokens) (Ai)
    function auxiliaryVariableRi(
        uint256 _userAvailableCollateralAmount,
        uint256 _userLiquidationTimeValue,
        uint256 _userCollateralAmount
    ) public pure returns (uint256 ri) {
        ri = _userCollateralAmount == 0 ? 0 : _userAvailableCollateralAmount * _userLiquidationTimeValue / _userCollateralAmount;
    }
}
