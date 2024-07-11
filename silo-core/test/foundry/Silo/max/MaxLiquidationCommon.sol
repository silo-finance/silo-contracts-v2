// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";


contract MaxLiquidationCommon is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    bool internal constant _RECEIVE_STOKENS = true;

    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_SILO);
        token1.setOnDemand(true);
    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow, bool _sameAsset) internal {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _depositCollateral(_collateral, borrower, _sameAsset);
        _borrow(_toBorrow, borrower, _sameAsset);

        _ensureBorrowerHasDebt();
    }

    function _ensureBorrowerHasDebt() internal view {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));
        assertGt(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower has debt balance");
        assertGt(silo0.getLtv(borrower), 0, "expect borrower has some LTV");
    }

    function _ensureBorrowerHasNoDebt() internal view {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower has NO debt balance");
        assertEq(silo0.getLtv(borrower), 0, "expect borrower has NO LTV");
    }

    function _assertBorrowerIsSolvent() internal view {
        assertTrue(silo1.isSolvent(borrower));

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), borrower);
        assertEq(collateralToLiquidate, 0);
        assertEq(debtToRepay, 0);

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), borrower);
        assertEq(collateralToLiquidate, 0);
        assertEq(debtToRepay, 0);
    }

    function _assertBorrowerIsNotSolvent(bool _hasBadDebt) internal {
        uint256 ltv = silo1.getLtv(borrower);
        emit log_named_decimal_uint("[_assertBorrowerIsNotSolvent] LTV", ltv, 16);

        assertFalse(silo1.isSolvent(borrower), "[_assertBorrowerIsNotSolvent] borrower is still solvent");

        if (_hasBadDebt) assertGt(ltv, 1e18, "[_assertBorrowerIsNotSolvent] LTV");
        else assertLe(ltv, 1e18, "[_assertBorrowerIsNotSolvent] LTV");
    }

    function _assertLTV100() internal {
        uint256 ltv = silo1.getLtv(borrower);
        emit log_named_decimal_uint("[_assertLTV100] LTV", ltv, 16);

        assertFalse(silo1.isSolvent(borrower), "[_assertLTV100] borrower is still solvent");

        assertEq(ltv, 1e18, "[_assertLTV100] LTV");
    }

    function _findLTV100() internal {
        uint256 prevLTV = silo1.getLtv(borrower);

        for (uint256 i = 1; i < 10000; i++) {
            vm.warp(i * 60 * 60 * 24);
            uint256 ltv = silo1.getLtv(borrower);

            emit log_named_decimal_uint("[_assertLTV100] LTV", ltv, 16);
            emit log_named_uint("[_assertLTV100] days", i);

            if (ltv == 1e18) revert("found");

            if (ltv != prevLTV && !silo1.isSolvent(borrower)) {
                emit log_named_decimal_uint("[_assertLTV100] prevLTV was", prevLTV, 16);
                revert("we found middle step between solvent and 100%");
            } else {
                prevLTV = silo1.getLtv(borrower);
            }
        }
    }

    function _moveTimeUntilInsolvent() internal {
        for (uint256 i = 1; i < 10000; i++) {
              emit log_named_decimal_uint("[_assertLTV100] LTV", silo1.getLtv(borrower), 16);
              emit log_named_uint("[_assertLTV100] days", i);

            bool isSolvent = silo1.isSolvent(borrower);

            if (!isSolvent) {
                emit log_named_string("[_findWrapForSolvency] user solvent?", isSolvent ? "yes" : "NO");
                emit log_named_decimal_uint("[_findWrapForSolvency] LTV", silo1.getLtv(borrower), 16);
                emit log_named_uint("[_findWrapForSolvency] days", i);

                return;
            }

            vm.warp(block.timestamp + i * 60 * 60 * 24);
        }
    }
}
