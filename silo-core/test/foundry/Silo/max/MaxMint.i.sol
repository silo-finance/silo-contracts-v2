// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxMintTest
*/
contract MaxMintTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxMint_emptySilo
    */
    function test_maxMint_emptySilo() public {
        uint256 maxMint = silo1.maxMint(depositor);
        assertEq(maxMint, type(uint128).max, "on empty silo, MAX is just no limit");
        _mintForBorrow(maxMint, maxMint, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_forBorrower
    */
    function test_maxMint_forBorrower_1token() public {
        uint256 _initialDeposit = 1e18;
        uint256 toBorrow = _initialDeposit / 3;
        bool sameAsset = true;

        _mintForBorrow(toBorrow, toBorrow, depositor);
        _mintCollateral(toBorrow * 2, toBorrow * 2, borrower, sameAsset);
        _borrow(toBorrow, borrower, sameAsset);

        assertEq(silo0.maxMint(borrower), _REAL_ASSETS_LIMIT, "real max deposit");
        assertEq(silo1.maxMint(borrower), _REAL_ASSETS_LIMIT - toBorrow * 3, "can deposit with debt");
    }

    function test_maxMint_forBorrower_2tokens() public {
        uint256 _initialDeposit = 1e18;
        uint256 toBorrow = _initialDeposit / 3;
        bool sameAsset;

        _mintForBorrow(toBorrow, toBorrow, depositor);
        _mintCollateral(toBorrow * 2, toBorrow * 2, borrower, sameAsset);
        _borrow(toBorrow, borrower, sameAsset);

        assertEq(silo0.maxMint(borrower), _REAL_ASSETS_LIMIT - toBorrow * 2, "real max deposit");
        assertEq(silo1.maxMint(borrower), _REAL_ASSETS_LIMIT - toBorrow, "can deposit with debt");
    }

    /*
    forge test -vv --ffi --mt test_maxMint_withDeposit_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxMint_withDeposit_1token_fuzz(uint128 _initialDeposit) public {
        _maxMint_withDeposit(_initialDeposit, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxMint_withDeposit_2tokens_fuzz(uint128 _initialDeposit) public {
        _maxMint_withDeposit(_initialDeposit, TWO_ASSETS);
    }

    function _maxMint_withDeposit(uint128 _initialDeposit, bool _sameAsset) private {
        vm.assume(_initialDeposit > 0);

        _depositForBorrow(_initialDeposit, depositor);

        uint256 maxMint = silo1.maxMint(depositor);
        emit log_named_decimal_uint("maxMint", maxMint, 18);

        assertEq(maxMint, _REAL_ASSETS_LIMIT - _initialDeposit, "with deposit, max is MAX - deposit");

        /// we probably can deposit more, but if for our way of defining max we get 0, we dont need to test deposit 0
        if (maxMint == 0) return;

        uint256 minted = _mintForBorrow(maxMint, maxMint, depositor);

        _assertWeCanBorrowAfterMaxDeposit(_initialDeposit + minted, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_withInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxMint_withInterest_1token_fuzz(
        uint256 _initialDeposit
    ) public {
        _maxMint_withInterest_fuzz(_initialDeposit, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxMint_withInterest_2tokens_fuzz(
        uint256 _initialDeposit
    ) public {
        _maxMint_withInterest_fuzz(_initialDeposit, TWO_ASSETS);
    }

    function _maxMint_withInterest_fuzz(uint256 _initialDeposit, bool _sameAsset) private {
        vm.assume(_initialDeposit > 3); // we need to be able /3
        vm.assume(_initialDeposit <= _REAL_ASSETS_LIMIT);

        uint256 toBorrow = _initialDeposit / 3;

        _depositForBorrow(_initialDeposit, depositor);
        _depositCollateral(toBorrow * 1e18, borrower, _sameAsset);
        _borrow(toBorrow, borrower, _sameAsset);

        vm.warp(block.timestamp + 100 days);

        uint256 maxMint = silo1.maxMint(depositor);
        vm.assume(maxMint > 0);

        emit log_named_decimal_uint("maxMint", maxMint, 18);

        token1.setOnDemand(true);
        uint256 minted = _mintForBorrow(maxMint, maxMint, depositor);
        token1.setOnDemand(false);

        _assertWeCanBorrowAfterMaxDeposit(minted, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_repayWithInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxMint_repayWithInterest_1token_fuzz(
        uint128 _initialDeposit
    ) public {
        // uint128 _initialDeposit = 1020847100762815390392;
        _maxMint_repayWithInterest(_initialDeposit, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxMint_repayWithInterest_2tokens_fuzz(
        uint128 _initialDeposit
    ) public {
        // uint128 _initialDeposit = 1020847100762815390392;
        _maxMint_repayWithInterest(_initialDeposit, TWO_ASSETS);
    }

    function _maxMint_repayWithInterest(uint128 _initialDeposit, bool _sameAsset) private {
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

        uint256 maxMint = silo1.maxMint(depositor);
        vm.assume(maxMint > 0);

        // all tokens to depositor, so we can transfer hi amounts
        vm.startPrank(borrower);
        token1.transfer(depositor, token1.balanceOf(borrower));

        token1.setOnDemand(true);
        _mintForBorrow(maxMint, maxMint, depositor);
        token1.setOnDemand(false);

        _assertWeCanBorrowAfterMaxDeposit(maxMint, borrower, _sameAsset);
    }

    // we check on silo1
    function _assertWeCanBorrowAfterMaxDeposit(uint256 _assets, address _borrower, bool _sameAsset) internal {
        uint256 collateral = _REAL_ASSETS_LIMIT * 1e18;
        emit log_named_decimal_uint("[_assertWeCanBorrowAfterMaxDeposit] collateral", collateral, 18);

        _depositCollateral(collateral, _borrower, _sameAsset);
        _borrow(_assets, _borrower, _sameAsset);
    }
}
