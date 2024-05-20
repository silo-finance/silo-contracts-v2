// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

contract InterestRateModelV2Impl is InterestRateModelV2 {
    function mockSetup(address _silo, int256 _ri, int256 _Tcrit) external {
        if (_Tcrit > type(int128).max) revert("[InterestRateModelV2Impl] _Tcrit overflow");
        if (_Tcrit < type(int128).min) revert("[InterestRateModelV2Impl] _Tcrit underflow");

        if (_ri > type(int128).max) revert("[InterestRateModelV2Impl] _ri overflow");
        if (_ri < type(int128).min) revert("[InterestRateModelV2Impl] _ri underflow");

        getSetup[_silo].Tcrit = int128(_Tcrit);
        getSetup[_silo].ri = int128(_ri);
    }

    function calculateRComp(
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        int256 _x
    ) external pure virtual returns (uint256 rcomp, bool overflow) {
        return _calculateRComp(_totalDeposits, _totalBorrowAmount, _x);
    }
}
