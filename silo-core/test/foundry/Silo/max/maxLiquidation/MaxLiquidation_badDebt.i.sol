// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MaxLiquidationTest} from "./MaxLiquidation.i.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationBadDebtTest

    this tests are for "normal" case, when bad debt
    there are no restrictions for input like in other cases, so this file has all scenarios
*/
contract MaxLiquidationBadDebtTest is MaxLiquidationTest {
    bool private constant _BAD_DEBT = true;

    function _maxLiquidation_partial_1token(uint128 _collateral, bool _receiveSToken, bool _self)
        internal
        virtual
        override
    {
        bool sameAsset = true;

        // this condition is to not have overflow: _collateral * 85
        vm.assume(_collateral < type(uint128).max / 85);

        uint256 toBorrow = _collateral * 85 / 100; // maxLT is 85%

        _createDebt(_collateral, toBorrow, sameAsset);

        vm.warp(block.timestamp + 1300 days); // initial time movement to speed up _moveTimeUntilInsolvent

        _moveTimeUntilBadDebt();

        _assertBorrowerIsNotSolvent(_BAD_DEBT);

        _executeLiquidationAndRunChecks(sameAsset, _receiveSToken, _self);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    function _maxLiquidation_partial_2tokens(uint128 _collateral, bool _receiveSToken, bool _self)
        internal
        virtual
        override
    {
        bool sameAsset = false;

        // this condition is to not have overflow: _collateral * 75
        vm.assume(_collateral < type(uint128).max / 75);

        uint256 toBorrow = _collateral * 75 / 100; // maxLT is 75%

        _createDebt(_collateral, toBorrow, sameAsset);

        vm.warp(block.timestamp + 50 days); // initial time movement to speed up _moveTimeUntilInsolvent

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        _moveTimeUntilBadDebt();

        _assertBorrowerIsNotSolvent(_BAD_DEBT);

        _executeLiquidationAndRunChecks(sameAsset, _receiveSToken, _self);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    function _withChunks() internal pure virtual override returns (bool) {
        return false;
    }
}
