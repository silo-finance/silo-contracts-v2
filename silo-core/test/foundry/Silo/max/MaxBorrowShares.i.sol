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
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;

    uint256 constant DEPOSIT_BEFORE = 1e18 + 9876543211;

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
    forge test -vv --ffi --mt test_maxBorrowShares_noCollateral
    */
    function test_maxBorrowShares_noCollateral_fuzz() public {
        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertEq(maxBorrowShares, 0, "no collateral - no borrow");

        _assertWeCanNotBorrowAnymore("NotEnoughLiquidity()");
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_withCollateral
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrowShares_withCollateral_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 2); // to allow any borrow amount, for 1 and 2 maxBorrowShares return 0.

        _depositForBorrow(_collateral, depositor);
        _deposit(_collateral, borrower);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertGt(maxBorrowShares, 0, "when collateral we expect something to borrow");

        _depositForBorrow(maxBorrowShares + 1, depositor);
        _borrowShares(maxBorrowShares, borrower);
        assertEq(silo1.maxBorrowShares(borrower), 0, "when borrow max, view should return 0");

        // _assertWeCanNotBorrowAnymore("AboveMaxLtv()"); TODO
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_collateralButNoLiquidity
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrowShares_collateralButNoLiquidity_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 3); // to allow any borrow twice

        _deposit(_collateral, borrower);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertEq(maxBorrowShares, 0, "no liquidity");
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_withDebt
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrowShares_withDebt_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 3); // to allow any borrow twice

        _deposit(_collateral, borrower);
        _depositForBorrow(_collateral, depositor);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower);

        vm.assume(maxBorrowShares / 3 > 0);
        _borrowShares(maxBorrowShares / 3, borrower);

        // now we have debt

        maxBorrowShares = silo1.maxBorrowShares(borrower);
        _borrowShares(maxBorrowShares, borrower);

        maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertEq(maxBorrowShares, 0, "at this point max should return 0");

        // _assertWeCanNotBorrowAnymore("AboveMaxLtv()"); // TODO
    }


    /*
    forge test -vv --ffi --mt test_maxBorrowShares_withInterest
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrowShares_withInterest_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 0); // to allow any borrow twice

        _deposit(_collateral, borrower);
        _depositForBorrow(_collateral, depositor);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower);
        vm.assume(maxBorrowShares / 3 > 0);
        _borrowShares(maxBorrowShares / 3, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);

        maxBorrowShares = silo1.maxBorrowShares(borrower);
        _borrowShares(maxBorrowShares, borrower);

        maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertLe(maxBorrowShares, 1, "at this point max should return 0, however we allow for 1wei precision error");

        // _assertWeCanNotBorrowAnymore("AboveMaxLtv()"); // TODO
    }

    /*
    forge test -vv --ffi --mt test_maxBorrowShares_repayWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrowShares_repayWithInterest_fuzz(uint64 _collateral) public {
        vm.assume(_collateral > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_collateral, depositor);

        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower);
        vm.assume(maxBorrowShares / 3 > 0);
        _borrowShares(maxBorrowShares / 3, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        token1.setOnDemand(true);
        _repayShares(1, IShareToken(debtShareToken).balanceOf(borrower), borrower);
        token1.setOnDemand(false);
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "all debt must be repay");

        maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertGt(maxBorrowShares, 0, "we can borrow again after repay");
        _borrowShares(maxBorrowShares, borrower);

        maxBorrowShares = silo1.maxBorrowShares(borrower);
        assertEq(maxBorrowShares, 0, "at this point max should return 0, however we allow for 1wei precision error");

        // _assertWeCanNotBorrowAnymore("AboveMaxLtv()"); // TODO
    }

    // we check on silo1
    function _assertWeCanNotBorrowAnymore() internal {
        vm.prank(borrower);
        // vm.expectRevert();
        silo1.borrow(1, borrower, borrower);
    }

    function _assertWeCanNotBorrowAnymore(string memory _error) internal {
        vm.expectRevert(bytes4(keccak256(abi.encodePacked(_error))));
        vm.prank(borrower);
        silo1.borrow(1, borrower, borrower);
    }
}
