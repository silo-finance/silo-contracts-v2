// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../contracts/models/AmmStateModel.sol";

contract StateModel is AmmStateModel {
    address immutable COLLATERAL_TOKEN;

    constructor (address _collateralToken) {
        COLLATERAL_TOKEN = _collateralToken;
    }

    function addLiquidity(address _user, uint256 _collateralAmount, uint256 _collateralValue)
        external
        returns (uint256 shares)
    {
        (,, shares) = _onAddLiquidityStateChange(COLLATERAL_TOKEN, _user, _collateralAmount, _collateralValue);
    }

    function withdrawLiquidity(address _user, uint256 _w) // solhint-disable-line function-max-lines
        external
        returns (uint256 debtAmount)
    {
        return _withdrawLiquidity(COLLATERAL_TOKEN, _user, _w);
    }

    function withdrawAllLiquidity(address _user) external returns (uint256 debtAmount) {
        return _withdrawAllLiquidity(COLLATERAL_TOKEN, _user);
    }

    function onSwapStateChange(uint256 _collateralOut, uint256 _debtIn) external {
        _onSwapStateChange(COLLATERAL_TOKEN, _collateralOut, _debtIn);
    }
}
