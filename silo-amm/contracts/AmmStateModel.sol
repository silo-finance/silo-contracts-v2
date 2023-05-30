// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;


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

    /// @dev our precision
    uint256 constant public DECIMALS = 1e18;

    // TODO we will need two total states for two flows tokenA -> tokenB, tokenB -> tokenA
    TotalState internal _totalState;

    // TODO we will need two states for each user, same as above
    mapping (address => UserPosition) internal _positions;

    error UserNotCleanedUp();
    error PercentOverflow();
    error NotEnoughAvailableCollateral();
    error CollateralOverflow();

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
    function addLiquidity(address _user, uint256 _collateralPrice, uint256 _collateralAmount)
        public
        returns (uint256 shares)
    {
        UserPosition storage position = _positions[_user];

        if (position.shares != 0) revert UserNotCleanedUp();

        uint256 dV;

        // unchecked: multiplication, because if we overflow on amount * price, then all the dexes will crash as well
        // we could check the math here of when we do insolvency calculations, but we should pick one place
        // unchecked: div(DECIMALS) because price is expected to be in 18 decimals, div is safe
        unchecked { dV = _collateralPrice * _collateralAmount / DECIMALS; }

        uint256 totalStateAvailableCollateral = _totalState.availableCollateral;
        uint256 totalStateShares = _totalState.shares;

        if (totalStateAvailableCollateral == 0) {
            shares = _collateralAmount;
        } else {
            uint256 collateralAmountTimesShares = _collateralAmount * totalStateShares;

            // TBD: shares transformation to/from exponential
            // unchecked: div is safe and we catched /0
            unchecked { shares = collateralAmountTimesShares / totalStateAvailableCollateral; }
        }

        // because of cleanup, there will no previous state, so this is all user initial values
        position.collateralAmount = _collateralAmount; // Ai + dC, but Ai is 0
        position.liquidationTimeValue = dV; // Vi + dV, but Vi is 0
        position.shares = shares;

        unchecked {
            // unchecked: this is basically token balance, it is enough to do check on transfer
            _totalState.collateralAmount += _collateralAmount;

            // unchecked: because if we overflow on value, then all the dexes will crash as well
            // we could check the math here of when we do insolvency calculations, but we should pick one place
            _totalState.liquidationTimeValue += dV;

            // unchecked availableCollateral is never more than collateralAmount,
            // so it is enough to check collateralAmount
            _totalState.availableCollateral = totalStateAvailableCollateral + _collateralAmount;
        }

        // shares value can be higher than amount, this is why += shares in not unchecked
        _totalState.shares = totalStateShares + shares;

        // now let's calculate R
        _totalState.R = _totalState.R + dV;
    }

    /// @dev state change on swap
    function onSwap(
        uint256 _collateralOut,
        uint256 _debtIn
    ) public {
        uint256 availableCollateral = _totalState.availableCollateral;

        // this check covers case when both or one is zero
        if (_collateralOut > availableCollateral) revert NotEnoughAvailableCollateral();

        uint256 newAvailableCollateral;
        // unchecked: we can not underflow because of check `if (_collateralOut > availableCollateral) revert`
        unchecked { newAvailableCollateral = availableCollateral - _collateralOut; }

        uint256 rTimesAvailableCollateral = _totalState.R * newAvailableCollateral;

        unchecked {
            // R should be scaled before other changes
            // unchecked: div is safe
            _totalState.R = rTimesAvailableCollateral / availableCollateral;

            // unchecked: only way to overflow is when: (1) our math is wrong or (2) we have overflow in token itself
            // if any of this cases true, then overflow makes no difference
            _totalState.debtAmount += _debtIn;
        }

        _totalState.availableCollateral = newAvailableCollateral;
    }

    /// @param _user owner of position
    /// @param _w fraction of user position that needs to be withdrawn, 0 < _w <= 100%
    /// @return debtAmount that is withdrawn
    function withdrawLiquidity( address _user, uint256 _w) // solhint-disable-line function-max-lines
        public
        returns (uint256 debtAmount)
    {
        if (_w > ONE) revert PercentOverflow();
        // TODO: make separate method for withdraw ALL
        // else if (_w == ONE) return withdrawAllLiquidity(_user);

        UserPosition storage storagePosition = _positions[_user];
        UserPosition memory position = _positions[_user];
        TotalState memory totalState = _totalState;

        uint256 ci = getCurrentlyAvailableCollateralForUser(
            totalState.shares,
            totalState.availableCollateral,
            position.shares
        );

        uint256 dC;

        // unchecked: we can uncheck `_w * ci` because below, we have `_w * position.collateralAmount`
        // and ci (available collateral) < position.collateralAmount
        unchecked { dC = _w * ci / ONE; }

        debtAmount = _w * userAvailableDebtAmount(
            totalState.debtAmount,
            totalState.liquidationTimeValue,
            totalState.R,
            position,
            ci
        );

        unchecked { debtAmount /= ONE; }

        uint256 dA = _w * position.collateralAmount;
        unchecked { dA /= ONE; }

        uint256 dV = _w * position.liquidationTimeValue;
        unchecked { dV /= ONE; }

        uint256 dS = _w * position.shares; // TODO support exponential
        unchecked { dS /= ONE; }

        // TODO in tests we will have to make sure, that when one of below subtraction end up being zero,
        //  others should be zeros as well

        uint256 newCollateralAmount;
        // unchecked: `dA` is fraction of position.collateralAmount
        unchecked { newCollateralAmount = position.collateralAmount - dA; }

        uint256 newLiquidationTimeValue;
        // unchecked: `dV` is fraction of position.liquidationTimeValue
        unchecked { newLiquidationTimeValue = position.liquidationTimeValue - dV; }

        // now let's calculate R, it must be done before other state is updated
        uint256 ri = auxiliaryVariableRi(ci, position.liquidationTimeValue, position.collateralAmount);

        uint256 riNew = newCollateralAmount == 0
            ? 0
            : (ci - dC) * newLiquidationTimeValue / newCollateralAmount;

        _totalState.R = totalState.R - ri + riNew;

        unchecked {
            // for all below `_totalState` changed, we decreasing state by fraction or at most whole
            // so as along as math is correct we should not underflow
            _totalState.collateralAmount = totalState.collateralAmount - dA;
            _totalState.liquidationTimeValue = totalState.liquidationTimeValue - dV;
            _totalState.shares = totalState.shares - dS;
            _totalState.availableCollateral = totalState.availableCollateral - dC;
            _totalState.debtAmount = totalState.debtAmount - debtAmount;

            storagePosition.shares = position.shares - dS;
        }

        storagePosition.collateralAmount = newCollateralAmount;
        storagePosition.liquidationTimeValue = newLiquidationTimeValue;
    }

    /// @notice The part of the user’s collateral amount that has already been swapped
    function userSwappedCollateral(address _user) public view returns (uint256 swappedCollateralFraction) {
        UserPosition memory position = _positions[_user];

        uint256 userAvailableCollateralAmount = getCurrentlyAvailableCollateralForUser(
            _totalState.shares,
            _totalState.availableCollateral,
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
    ) public pure returns (uint256 amount) {
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
    ) public pure returns (uint256 amount) {
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
    ) public pure returns (uint256 ri) {
        if (_userCollateralAmount == 0) return 0;

        ri = _userAvailableCollateralAmount * _userLiquidationTimeValue;
        unchecked { ri /= _userCollateralAmount; }
    }
}
