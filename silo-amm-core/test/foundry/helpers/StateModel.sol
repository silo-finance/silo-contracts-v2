// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../contracts/AmmStateModel.sol";

contract StateModel is AmmStateModel {
    address immutable _COLLATERAL;

    constructor (address _collateral) {
        _COLLATERAL = _collateral;
    }

    function addLiquidity(address _user, uint256 _collateralAmount, uint256 _collateralValue)
        external
        returns (uint256 shares)
    {
        (,, shares) = _onAddLiquidityStateChange(_COLLATERAL, _user, _collateralAmount, _collateralValue);
    }

    function withdrawLiquidity(address _user, uint256 _w) // solhint-disable-line function-max-lines
        external
        returns (uint256 debtAmount)
    {
        return _withdrawLiquidity(_COLLATERAL, _user, _w);
    }

    function withdrawAllLiquidity(address _user) external returns (uint256 debtAmount) {
        return _withdrawAllLiquidity(_COLLATERAL, _user);
    }

    function onSwapStateChange(uint256 _collateralOut, uint256 _debtIn) external {
        _onSwapStateChange(_COLLATERAL, _collateralOut, _debtIn);
    }
}
