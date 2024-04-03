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
    forge test -vv --ffi --mc MaxDepositTest
*/
contract MaxDepositTest is SiloLittleHelper, Test {
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;

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
    forge test -vv --ffi --mt test_maxDeposit_cap
    */
    function test_maxDeposit_cap() public {
        assertEq(silo0.maxDeposit(address(1)), 2 ** 128 - 1, "ERC4626 expect to return 2 ** 256 - 1");
        assertEq(silo0.maxMint(address(1)), 2 ** 128 - 1, "ERC4626 expect to return 2 ** 256 - 1 (maxMint)");
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_emptySilo
    */
    function test_maxDeposit_emptySilo() public {
        uint256 maxDeposit = silo1.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint128).max, "on empty silo, MAX is just no limit");
        _depositForBorrow(maxDeposit, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_forBorrower
    */
    function test_maxDeposit_forBorrower_2tokens() public {
        uint256 _initialDeposit = 1e18;
        uint256 toBorrow = _initialDeposit / 3;
        bool sameAsset;

        _depositForBorrow(toBorrow, depositor);
        _deposit(toBorrow * 2, borrower);
        _borrow(toBorrow, borrower, sameAsset);

        assertEq(silo0.maxDeposit(borrower), _REAL_ASSETS_LIMIT - toBorrow * 2, "real max deposit");
        assertEq(silo1.maxDeposit(borrower), _REAL_ASSETS_LIMIT - toBorrow, "can deposit with debt");
    }

    function test_maxDeposit_forBorrower_1token() public {
        uint256 _initialDeposit = 1e18;
        uint256 toBorrow = _initialDeposit / 3;
        bool sameAsset = true;

        _depositForBorrow(toBorrow, depositor);
        _depositForBorrow(toBorrow * 2, borrower);
        _borrow(toBorrow, borrower, sameAsset);

        assertEq(silo0.maxDeposit(borrower), _REAL_ASSETS_LIMIT, "real max deposit");
        assertEq(silo1.maxDeposit(borrower), _REAL_ASSETS_LIMIT - toBorrow * 3, "can deposit with debt");
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_withDeposit_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxDeposit_withDeposit_1token_fuzz(uint128 _initialDeposit) public {
        _maxDeposit_withDeposit(_initialDeposit, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxDeposit_withDeposit_2tokena_fuzz(uint128 _initialDeposit) public {
        _maxDeposit_withDeposit(_initialDeposit, TWO_ASSETS);
    }

    function _maxDeposit_withDeposit(uint128 _initialDeposit, bool _sameAsset) private {
        vm.assume(_initialDeposit > 0);

        _depositForBorrow(_initialDeposit, depositor);

        uint256 maxDeposit = silo1.maxDeposit(depositor);
        emit log_named_decimal_uint("maxDeposit", maxDeposit, 18);

        assertEq(maxDeposit, _REAL_ASSETS_LIMIT - _initialDeposit, "with deposit, max is: MAX - deposit");

        /// we probably can deposit more, but if for our way of defining max we get 0, we dont need to test deposit 0
        if (maxDeposit == 0) return;

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanBorrowAfterMaxDeposit(_initialDeposit + maxDeposit, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_withInterest_
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_maxDeposit_withInterest_1token_fuzz(
        uint256 _initialDeposit
    ) public {
         // uint256 _initialDeposit = 17100;
        _maxDeposit_withInterest_fuzz(_initialDeposit, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_maxDeposit_withInterest_2tokens_fuzz(
        uint256 _initialDeposit
    ) public {
        _maxDeposit_withInterest_fuzz(_initialDeposit, TWO_ASSETS);
    }

    function _maxDeposit_withInterest_fuzz(uint256 _initialDeposit, bool _sameAsset) public {
        vm.assume(_initialDeposit > 3); // we need to be able /3
        vm.assume(_initialDeposit <= _REAL_ASSETS_LIMIT);

        uint256 toBorrow = _initialDeposit / 3;

        _depositForBorrow(_initialDeposit, depositor);
        emit log_named_decimal_uint("depositor deposits", _initialDeposit, 18);

        _depositCollateral(toBorrow * 1e18, borrower, _sameAsset);
        emit log_named_decimal_uint("borrower deposits", toBorrow * 1e18, 18);

        _borrow(toBorrow, borrower, _sameAsset);
        emit log_named_decimal_uint("borrower borrow", toBorrow, 18);

        vm.warp(block.timestamp + 100 days);

        uint256 maxDeposit = silo1.maxDeposit(depositor);
        vm.assume(maxDeposit > 0);

        emit log_named_decimal_uint("maxDeposit", maxDeposit, 18);

        assertLe(
            maxDeposit,
            _REAL_ASSETS_LIMIT - _initialDeposit,
            "with interest we expecting less than simply sub the initial deposit"
        );

        if (silo1.previewDeposit(maxDeposit) == 0) {
            uint256 margin = 2;
            assertLt(maxDeposit, margin, "we know for small assets if there is already big numbers, max can be 'invalid'");
            assertGt(silo1.getCollateralAssets(), _REAL_ASSETS_LIMIT - margin, "must be big number");
            return;
        }

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanBorrowAfterMaxDeposit(maxDeposit, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_repayWithInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxDeposit_repayWithInterest_1token_fuzz(
        uint64 _initialDeposit // 64b because this is initial deposit, and we care about max after initial
    ) public {
        _maxDeposit_repayWithInterest_fuzz(_initialDeposit, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxDeposit_repayWithInterest_2tokens_fuzz(
        uint64 _initialDeposit // 64b because this is initial deposit, and we care about max after initial
    ) public {
        _maxDeposit_repayWithInterest_fuzz(_initialDeposit, TWO_ASSETS);
    }

    function _maxDeposit_repayWithInterest_fuzz(uint64 _initialDeposit, bool _sameAsset) public {
        // uint128 _initialDeposit = 1020847100762815390392;
        vm.assume(_initialDeposit / 3 > 0);

        uint256 toBorrow = _initialDeposit / 3;

        _depositForBorrow(toBorrow + 1e18, depositor);

        _depositCollateral(toBorrow * 1e18, borrower, _sameAsset);
        _borrow(toBorrow, borrower, _sameAsset);

        vm.warp(block.timestamp + 100 days);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        token1.setOnDemand(true);
        _repayShares(1, IShareToken(debtShareToken).balanceOf(borrower), borrower);
        token1.setOnDemand(false);

        assertGt(token1.balanceOf(address(silo1)), toBorrow, "we expect to repay with interest");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "all debt must be repay");

        uint256 maxDeposit = silo1.maxDeposit(depositor);

        if (silo1.previewDeposit(maxDeposit) == 0) {
            uint256 margin = 2;
            assertLt(maxDeposit, margin, "we know for small assets if there is already big numbers, max can be 'invalid'");
            assertGt(silo1.getCollateralAssets(), _REAL_ASSETS_LIMIT - margin, "must be big number");
            return;
        }

        vm.startPrank(borrower);
        token1.transfer(depositor, token1.balanceOf(borrower));

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanBorrowAfterMaxDeposit(maxDeposit, borrower, _sameAsset);
    }

    // we check on silo1
    function _assertWeCanBorrowAfterMaxDeposit(uint256 _assets, address _borrower, bool _sameAsset) internal {
        uint256 collateral = _REAL_ASSETS_LIMIT * 1e18;
        emit log_named_decimal_uint("[_assertWeCanBorrowAfterMaxDeposit] collateral", collateral, 18);
        _depositCollateral(collateral, _borrower, _sameAsset);
        emit log_named_decimal_uint("[_assertWeCanBorrowAfterMaxDeposit] _assets", _assets, 18);
        emit log_named_decimal_uint("[_assertWeCanBorrowAfterMaxDeposit] LTV preview", _assets * 1e18 / collateral, 16);
        emit log_named_decimal_uint("[_assertWeCanBorrowAfterMaxDeposit] LTV0", siloLens.getLtv(silo0, _borrower), 16);
        emit log_named_decimal_uint("[_assertWeCanBorrowAfterMaxDeposit] LTV1", siloLens.getLtv(silo1, _borrower), 16);

        _borrow(_assets, _borrower, _sameAsset);
    }
}
