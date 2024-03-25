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
    forge test -vv --ffi --mc MaxBorrowSharesTest
*/
contract MaxBorrowSharesTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;
    bool sameToken;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_noCollateral
    */
    function test_maxBorrowShares_noCollateral() public {
        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);
        assertEq(maxBorrowShares, 0, "no collateral - no borrowShares");

        _assertMaxBorrowSharesIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_withCollateral
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrowShares_withCollateral_fuzz(
        uint128 _collateral, uint128 _liquidity
    ) public {
        // (uint128 _collateral, uint128 _liquidity) = (3, 2);
        vm.assume(_liquidity > 0);
        vm.assume(_collateral > 0);

        _depositForBorrow(_liquidity, depositor);
        _deposit(_collateral, borrower);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);
        vm.assume(maxBorrowShares > 0);

        _assertWeCanNotBorrowAboveMax(maxBorrowShares, 2);

        _assertMaxBorrowSharesIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_collateralButNoLiquidity
    */
    /// forge-config: core.fuzz.runs = 100
    function test_maxBorrowShares_collateralButNoLiquidity_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 3); // to allow any borrowShares twice

        _deposit(_collateral, borrower);

        _assertWeCanNotBorrowAboveMax(0);
        _assertMaxBorrowSharesIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_withDebt
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrowShares_withDebt_fuzz(uint128 _collateral, uint128 _liquidity) public {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);

        uint256 firstBorrow = maxBorrowShares / 3;
        vm.assume(firstBorrow > 0);
        _borrowShares(firstBorrow, borrower);

        // now we have debt

        maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);

        _assertWeCanNotBorrowAboveMax(maxBorrowShares, 2);
        _assertMaxBorrowSharesIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrowShares_withInterest_fuzz(
        uint128 _collateral,
        uint128 _liquidity
    ) public {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);
        // TODO  +protected, and for maxBorrow

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);
        uint256 firstBorrow = maxBorrowShares / 3;
        emit log_named_uint("____ firstBorrow", firstBorrow);

        vm.assume(firstBorrow > 0);
        _borrowShares(firstBorrow, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);

        maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);
        emit log_named_uint("____ maxBorrowShares", maxBorrowShares);

        _assertWeCanNotBorrowAboveMax(maxBorrowShares, 3);
        _assertMaxBorrowSharesIsZeroAtTheEnd(1);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_repayWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 5000
    function test_maxBorrowShares_repayWithInterest_fuzz(
        uint64 _collateral,
        uint128 _liquidity
    ) public {
        // (uint64 _collateral, uint128 _liquidity) = (7117, 7095);
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);
        // TODO  +protected, and same for maxBorrow

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);
        uint256 firstBorrow = maxBorrowShares / 3;
        emit log_named_uint("____ firstBorrow", firstBorrow);

        vm.assume(firstBorrow > 0);
        _borrowShares(firstBorrow, borrower);

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

        maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);
        emit log_named_uint("____ maxBorrowShares", maxBorrowShares);

        _assertWeCanNotBorrowAboveMax(maxBorrowShares, 3);
        _assertMaxBorrowSharesIsZeroAtTheEnd(1);
    }

    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow) internal {
        _assertWeCanNotBorrowAboveMax(_maxBorrow, 1);
    }

    /// @param _precision is needed because we count for precision error and we allow for 1 wei diff
    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrowShares, uint256 _precision) internal {
        emit log_named_uint("------- QA: _assertWeCanNotBorrowAboveMax shares", _maxBorrowShares);
        emit log_named_uint("------- QA: _assertWeCanNotBorrowAboveMax _precision", _precision);

        uint256 toBorrow = _maxBorrowShares + _precision;

        uint256 liquidity = silo1.getLiquidity();
        uint256 maxBorrowAssets = silo1.convertToAssets(_maxBorrowShares, ISilo.AssetType.Debt);

        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] maxBorrowAssets", maxBorrowAssets, 18);
        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] liquidity", liquidity, 18);
        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] balanceOf", token1.balanceOf(address(silo1)), 18);
        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax]  toBorrow", toBorrow, 18);

        if (maxBorrowAssets > liquidity) {
            emit log("MAX returned shares, that translate for TOO MUCH assets");
            // assertLe(maxBorrowAssets, liquidity, "MAX returned shares, that translate for TOO MUCH assets");
        }

        vm.prank(borrower);
        try silo1.borrowShares(toBorrow, borrower, borrower, sameToken) returns (uint256) {
            revert("[borrowShares] we expect tx to be reverted!");
        } catch (bytes memory data) {
            bytes4 errorType = bytes4(data);

            bytes4 error1 = bytes4(keccak256(abi.encodePacked("NotEnoughLiquidity()")));
            bytes4 error2 = bytes4(keccak256(abi.encodePacked("AboveMaxLtv()")));

            if (errorType != error1 && errorType != error2) {
                revert("we need to revert with NotEnoughLiquidity or AboveMaxLtv");
            }
        }

        if (_maxBorrowShares > 0) {
            emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] _maxBorrow > 0 YES, borrowing max", _maxBorrowShares, 18);
            vm.prank(borrower);
            silo1.borrowShares(_maxBorrowShares, borrower, borrower, sameToken);
        }
    }

    function _assertMaxBorrowSharesIsZeroAtTheEnd() internal {
        _assertMaxBorrowSharesIsZeroAtTheEnd(0);
    }

    function _assertMaxBorrowSharesIsZeroAtTheEnd(uint256 _precision) internal {
        emit log_named_uint("=================== _assertMaxBorrowIsZeroAtTheEnd =================== +/-", _precision);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, sameToken);

        assertLe(
            maxBorrowShares,
            _precision,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_precision)))
        );
    }
}
