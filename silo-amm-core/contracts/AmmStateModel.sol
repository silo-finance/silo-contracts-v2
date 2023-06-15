// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./interfaces/IAmmStateModel.sol";


/// @dev annotations like (A) or (Ci) is reference to the internal document that describes model in mathematical way.
abstract contract AmmStateModel is IAmmStateModel {
    /// @dev 100%
    uint256 constant public HUNDRED = 1e18;

    /// @dev two states for two tokens, token => state
    mapping (address => TotalState) internal _totalStates;

    /// @dev collateral token => user => position
    mapping (address => mapping (address => UserPosition)) internal _positions;

    function getTotalState(address _collateral) external view returns (TotalState memory) {
        return _totalStates[_collateral];
    }

    function positions(address _collateral, address _user) external view returns (UserPosition memory) {
        return _positions[_collateral][_user];
    }

    /// @notice The part of the user’s collateral amount that has already been swapped
    function userSwappedCollateral(address _collateral, address _user)
        public
        view
        returns (uint256 swappedCollateralFraction)
    {
        UserPosition memory position = _positions[_collateral][_user];

        uint256 userAvailableCollateralAmount = getCurrentlyAvailableCollateralForUser(
            _totalStates[_collateral].shares,
            _totalStates[_collateral].availableCollateral,
            position.shares
        );

        unchecked {
            // userAvailableCollateralAmount is never greater than collateralAmount, and division is safe
            swappedCollateralFraction = position.collateralAmount == 0
                ? 0
                : (position.collateralAmount - userAvailableCollateralAmount) / position.collateralAmount;
        }
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
    )
        public
        pure
        returns (uint256 amount)
    {
        return _totalShares == 0 ? 0 : _userShares * _totalAvailableCollateral / _totalShares;
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
    )
        public
        pure
        returns (uint256 amount)
    {
        uint256 ri = auxiliaryVariableRi(
            _userAvailableCollateralAmount,
            _position.liquidationTimeValue,
            _position.collateralAmount
        );

        uint256 divider = _totalLiquidationTimeValue - _totalR;
        if (divider == 0) return 0;

        amount = (_position.liquidationTimeValue - ri) * _totalDebtAmount;
        unchecked { amount /= divider; }
    }

    /// @param _userAvailableCollateralAmount amount of collateral currently available to user (Ci)
    /// @param _userLiquidationTimeValue liquidation-time value of collateral provided by the user (Vi)
    /// @param _userCollateralAmount amount of collateral historically provided by the user
    /// (denominated in collateral tokens) (Ai)
    function auxiliaryVariableRi(
        uint256 _userAvailableCollateralAmount,
        uint256 _userLiquidationTimeValue,
        uint256 _userCollateralAmount
    )
        public
        pure
        returns (uint256 ri)
    {
        if (_userCollateralAmount == 0) return 0;

        ri = _userAvailableCollateralAmount * _userLiquidationTimeValue;
        unchecked { ri /= _userCollateralAmount; }
    }


    // TODO bulk addLiquidity needed?

    /// @notice endpoint for liquidation, here borrower collateral is added as liquidity
    /// @dev User adds `dC` units of collateral to the pool and receives shares.
    /// Liquidation-time value of the collateral at the current spot price P(t) is added to the user’s count.
    /// The variable R is updated so that it keeps track of the sum of Ri
    /// @param _collateral address of collateral token that is been deposited into pool
    /// @param _user depositor, owner of position
    /// @param _collateralAmount amount of collateral
    /// @param _collateralValue value that is: collateralPrice * collateralAmount / DECIMALS,
    //. where collateralPrice is current price P(T) of collateral
    function _stateChangeOnAddLiquidity(
        address _collateral,
        address _user,
        uint256 _collateralAmount,
        uint256 _collateralValue
    )
        internal
        returns (uint256 shares)
    {
        UserPosition storage position = _positions[_collateral][_user];

        if (position.shares != 0) revert USER_NOT_CLEANED_UP();

        uint256 totalStateAvailableCollateral = _totalStates[_collateral].availableCollateral;
        uint256 totalStateShares = _totalStates[_collateral].shares;

        if (totalStateAvailableCollateral == 0) {
            shares = _collateralAmount;
        } else {
            uint256 collateralAmountTimesShares = _collateralAmount * totalStateShares;

            // TBD: shares transformation to/from exponential
            // unchecked: div is safe and we caught /0 in if above
            unchecked { shares = collateralAmountTimesShares / totalStateAvailableCollateral; }
        }

        // because of cleanup, there will no previous state, so this is all user initial values
        position.collateralAmount = _collateralAmount; // Ai + dC, but Ai is 0
        position.liquidationTimeValue = _collateralValue; // Vi + dV, but Vi is 0
        position.shares = shares;

        unchecked {
            // unchecked: this is basically token balance, it is enough to do check on transfer
            _totalStates[_collateral].collateralAmount += _collateralAmount;

            // unchecked: because if we overflow on value, then all the dexes will crash as well
            // we could check the math here of when we do insolvency calculations, but we should pick one place
            _totalStates[_collateral].liquidationTimeValue += _collateralValue;

            // unchecked availableCollateral is never more than collateralAmount,
            // so it is enough to check collateralAmount
            _totalStates[_collateral].availableCollateral = totalStateAvailableCollateral + _collateralAmount;
        }

        // shares value can be higher than amount, this is why += shares in not unchecked
        _totalStates[_collateral].shares = totalStateShares + shares;

        // now let's calculate R
        _totalStates[_collateral].R = _totalStates[_collateral].R + _collateralValue;
    }

    /// @return debtAmount amount of debt that will be withdrawn
    // solhint-disable-next-line function-max-lines
    function _withdrawLiquidity(address _collateral, address _user, uint256 _w)
        internal
        returns (uint256 debtAmount)
    {
        UserPosition storage storagePosition = _positions[_collateral][_user];
        UserPosition memory cachedPosition = _positions[_collateral][_user];
        TotalState memory totalState = _totalStates[_collateral];

        uint256 ci = getCurrentlyAvailableCollateralForUser(
            totalState.shares,
            totalState.availableCollateral,
            cachedPosition.shares
        );

        Deltas memory deltas;

        // unchecked: we can uncheck `_w * ci` because below, we have `_w * position.collateralAmount`
        // and ci (available collateral) < position.collateralAmount
        unchecked { deltas.dC = _w * ci / HUNDRED; }

        debtAmount = _w * userAvailableDebtAmount(
            totalState.debtAmount,
            totalState.liquidationTimeValue,
            totalState.R,
            cachedPosition,
            ci
        );

        unchecked { debtAmount /= HUNDRED; }

        deltas.dA = _w * cachedPosition.collateralAmount;
        unchecked { deltas.dA /= HUNDRED; }

        deltas.dV = _w * cachedPosition.liquidationTimeValue;
        unchecked { deltas.dV /= HUNDRED; }

        deltas.dS = _w * cachedPosition.shares; // TODO support exponential
        unchecked { deltas.dS /= HUNDRED; }

        // TODO in tests we will have to make sure, that when one of below subtraction end up being zero,
        // others should be zeros as well

        uint256 newCollateralAmount;
        // unchecked: `dA` is fraction of position.collateralAmount
        unchecked { newCollateralAmount = cachedPosition.collateralAmount - deltas.dA; }

        uint256 newLiquidationTimeValue;
        // unchecked: `dV` is fraction of position.liquidationTimeValue
        unchecked { newLiquidationTimeValue = cachedPosition.liquidationTimeValue - deltas.dV; }

        // now let's calculate R, it must be done before other state is updated
        uint256 ri = auxiliaryVariableRi(ci, cachedPosition.liquidationTimeValue, cachedPosition.collateralAmount);

        uint256 riNew = newCollateralAmount == 0
            ? 0
            : (ci - deltas.dC) * newLiquidationTimeValue / newCollateralAmount;

        _totalStates[_collateral].R = totalState.R - ri + riNew;

        unchecked {
            // for all below `_totalStates` changed, we decreasing state by fraction or at most whole
            // so as along as math is correct we should not underflow
            _totalStates[_collateral].collateralAmount = totalState.collateralAmount - deltas.dA;
            _totalStates[_collateral].liquidationTimeValue = totalState.liquidationTimeValue - deltas.dV;
            _totalStates[_collateral].shares = totalState.shares - deltas.dS;
            _totalStates[_collateral].availableCollateral = totalState.availableCollateral - deltas.dC;
            _totalStates[_collateral].debtAmount = totalState.debtAmount - debtAmount;

            storagePosition.shares = cachedPosition.shares - deltas.dS;
        }

        storagePosition.collateralAmount = newCollateralAmount;
        storagePosition.liquidationTimeValue = newLiquidationTimeValue;
    }

    /// @param _user owner of position
    /// @return debtAmount that is withdrawn
    function _withdrawAllLiquidity(address _collateral, address _user) internal returns (uint256 debtAmount) {
        UserPosition storage storagePosition = _positions[_collateral][_user];
        UserPosition memory cachedPosition = storagePosition;
        TotalState memory totalState = _totalStates[_collateral];

        uint256 ci = getCurrentlyAvailableCollateralForUser(
            totalState.shares,
            totalState.availableCollateral,
            cachedPosition.shares
        );

        debtAmount = userAvailableDebtAmount(
            totalState.debtAmount,
            totalState.liquidationTimeValue,
            totalState.R,
            cachedPosition,
            ci
        );

        // now let's calculate R, it must be done before other state is updated
        uint256 ri = auxiliaryVariableRi(ci, cachedPosition.liquidationTimeValue, cachedPosition.collateralAmount);

        _totalStates[_collateral].R = totalState.R - ri;

        unchecked {
            // for all below `_totalStates` changed, we decreasing state by fraction or at most whole
            // so as along as math is correct we should not underflow
            _totalStates[_collateral].collateralAmount =
                totalState.collateralAmount - cachedPosition.collateralAmount;

            _totalStates[_collateral].liquidationTimeValue =
                totalState.liquidationTimeValue - cachedPosition.liquidationTimeValue;

            _totalStates[_collateral].shares = totalState.shares - cachedPosition.shares;
            _totalStates[_collateral].availableCollateral = totalState.availableCollateral - ci;
            _totalStates[_collateral].debtAmount = totalState.debtAmount - debtAmount;
        }

        storagePosition.shares = 0;
        storagePosition.collateralAmount = 0;
        storagePosition.liquidationTimeValue = 0;
    }

    /// @dev state change on swap
    function _onSwapStateChange(
        address _collateral,
        uint256 _collateralOut,
        uint256 _debtIn
    ) internal {
        uint256 availableCollateral = _totalStates[_collateral].availableCollateral;

        // this check covers case when both or one is zero
        if (_collateralOut > availableCollateral) revert NOT_ENOUGH_AVAILABLE_COLLATERAL();
        if (availableCollateral == 0) revert NO_COLLATERAL();

        uint256 newAvailableCollateral;
        // unchecked: we can not underflow because of check `if (_collateralOut > availableCollateral) revert`
        unchecked { newAvailableCollateral = availableCollateral - _collateralOut; }

        uint256 rTimesAvailableCollateral = _totalStates[_collateral].R * newAvailableCollateral;

        unchecked {
            // R should be scaled before other changes
            // unchecked: div is safe
            _totalStates[_collateral].R = rTimesAvailableCollateral / availableCollateral;

            // unchecked: only way to overflow is when: (1) our math is wrong or (2) we have overflow in token itself
            // if any of this cases true, then overflow makes no difference
            _totalStates[_collateral].debtAmount += _debtIn;
        }

        _totalStates[_collateral].availableCollateral = newAvailableCollateral;
    }
}
