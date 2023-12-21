// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxBorrowTest
*/
contract MaxBorrowTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_noCollateral
    */
    function test_maxBorrow_noCollateral() public {
        uint256 maxBorrow = silo1.maxBorrow(borrower);
        assertEq(maxBorrow, 0, "no collateral - no borrow");

        _assertWeCanNotBorrowAboveMax(0);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withCollateral
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_withCollateral_fuzz(
        uint128 _collateral,
        uint128 _liquidity
    ) public {
        vm.assume(_liquidity > 0);
        vm.assume(_collateral > 0);

        _depositForBorrow(_liquidity, depositor);
        _deposit(_collateral, borrower);

        uint256 maxBorrow = silo1.maxBorrow(borrower);
        emit log_named_decimal_uint("maxBorrow", maxBorrow, 18);

        _assertWeCanNotBorrowAboveMax(maxBorrow);

        _assertMaxBorrowIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_collateralButNoLiquidity
    */
    /// forge-config: core.fuzz.runs = 100
    function test_maxBorrow_collateralButNoLiquidity_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 0);

        _deposit(_collateral, borrower);

        _assertMaxBorrowIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withDebt
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_withDebt_fuzz(uint128 _collateral, uint128 _liquidity) public {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        uint256 firstBorrow = maxBorrow / 3;
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower);

        // now we have debt

        maxBorrow = silo1.maxBorrow(borrower);
        _assertWeCanNotBorrowAboveMax(maxBorrow);

        _assertMaxBorrowIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_withInterest_fuzz(
        uint128 _collateral,
        uint128 _liquidity
    ) public {
//         (uint128 _collateral, uint128 _liquidity) = (64099903089467212573385554129187123252, 73362960447100600398853614451545866240);

        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        uint256 firstBorrow = maxBorrow / 3;
        emit log_named_uint("firstBorrow", firstBorrow);
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);

        maxBorrow = silo1.maxBorrow(borrower);
        emit log_named_uint("maxBorrow", maxBorrow);

        _assertWeCanNotBorrowAboveMax(maxBorrow, 3);

        _assertMaxBorrowIsZeroAtTheEnd(1);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_repayWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_repayWithInterest_fuzz(
        uint64 _collateral,
        uint128 _liquidity
    ) public {
//        (uint64 _collateral, uint128 _liquidity) = (11051, 16245);
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        uint256 firstBorrow = maxBorrow / 3;
        emit log_named_uint("firstBorrow", firstBorrow);
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);
        emit log("----- time travel -----");

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        token1.setOnDemand(true);
        uint256 debt = IShareToken(debtShareToken).balanceOf(borrower);
        emit log_named_decimal_uint("user shares", debt, 18);
        uint256 debtToRepay = debt * 9 / 10 == 0 ? 1 : debt * 9 / 10;
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);

        _repayShares(1, debtToRepay, borrower);
        token1.setOnDemand(false);

        // maybe we have some debt left, maybe not

        maxBorrow = silo1.maxBorrow(borrower);
        assertGt(maxBorrow, 0, "we can borrow again after repay");

        _assertWeCanNotBorrowAboveMax(maxBorrow, 2);

        _assertMaxBorrowIsZeroAtTheEnd();
    }

    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow) internal {
        _assertWeCanNotBorrowAboveMax(_maxBorrow, 1);
    }

    /// @param _precision is needed because we count for precision error and we allow for 1 wei diff
    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow, uint256 _precision) internal {
        emit log_string("------- QA: _assertWeCanNotBorrowAboveMax");

        uint256 toBorrow;
        string memory revertError;

        uint256 liquidity = silo1.getLiquidityAccrueInterest(ISilo.AssetType.Collateral);

        if (_maxBorrow == liquidity) {
            emit log_string("max is cap by liquidity");
            revertError = "NotEnoughLiquidity()";
            toBorrow = _maxBorrow + 1;
        } else if (_maxBorrow + _precision > liquidity) {
            emit log_string("max (+precision) is cap by liquidity");
            toBorrow = _maxBorrow + _precision;
            revertError = "NotEnoughLiquidity()";
        } else {
            emit log_string("max (+precision) is below liquidity, so we should be limit by max LTV");
            toBorrow = _maxBorrow + _precision;
            revertError = "AboveMaxLtv()";
        }

        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] liquidity", liquidity, 18);
        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax]  toBorrow", toBorrow, 18);
        emit log_named_string("[_assertWeCanNotBorrowAboveMax] revertError", revertError);

        vm.expectRevert(bytes4(keccak256(abi.encodePacked(revertError))));
        vm.prank(borrower);
        silo1.borrow(toBorrow, borrower, borrower);

        if (_maxBorrow > 0) {
            emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] _maxBorrow > 0 YES, borrowing max", _maxBorrow, 18);
            vm.prank(borrower);
            silo1.borrow(_maxBorrow, borrower, borrower);
        }
    }

    function _assertMaxBorrowIsZeroAtTheEnd() internal {
        _assertMaxBorrowIsZeroAtTheEnd(0);
    }

    function _assertMaxBorrowIsZeroAtTheEnd(uint256 _precision) internal {
        emit log_named_uint("=================== _assertMaxBorrowIsZeroAtTheEnd =================== +/-", _precision);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        assertLe(
            maxBorrow,
            _precision,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_precision)))
        );
    }
}
