// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc MaxBorrowTest
*/
contract MaxBorrowTest is SiloLittleHelper, Test {
    using Strings for uint256;

    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public virtual {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.SILO_LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_noCollateral
    */
    function test_maxBorrow_noCollateral_1() public {
        _maxBorrow_noCollateral(SAME_ASSET);
    }

    function test_maxBorrow_noCollateral_2() public {
        _maxBorrow_noCollateral(TWO_ASSETS);
    }

    function _maxBorrow_noCollateral(bool _sameAsset) public {
        uint256 maxBorrow = _maxBorrow1(_sameAsset);
        assertEq(maxBorrow, 0, "no collateral - no borrow");

        _assertWeCanNotBorrowAboveMax(0, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withCollateral_
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withCollateral_1token_fuzz(
        uint128 _collateral, uint128 _liquidity
    ) public {
        // uint128 _collateral = 401;
        // uint128 _liquidity = 1;
        _maxBorrow_withCollateral_fuzz(_collateral, _liquidity, ISilo.CollateralType.Collateral, SAME_ASSET);
    }

    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withCollateral_protected_1token_fuzz(
        uint128 _collateral, uint128 _liquidity
    ) public {
        _maxBorrow_withCollateral_fuzz(_collateral, _liquidity, ISilo.CollateralType.Protected, SAME_ASSET);
    }

    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withCollateral_2tokens_fuzz(
        uint128 _collateral, uint128 _liquidity
    ) public {
        // uint128 _collateral = 401;
        // uint128 _liquidity = 1;
        _maxBorrow_withCollateral_fuzz(_collateral, _liquidity, ISilo.CollateralType.Collateral, TWO_ASSETS);
    }

    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withCollateral_protected_2tokens_fuzz(
        uint128 _collateral, uint128 _liquidity
    ) public {
        _maxBorrow_withCollateral_fuzz(_collateral, _liquidity, ISilo.CollateralType.Protected, TWO_ASSETS);
    }

    function _maxBorrow_withCollateral_fuzz(
        uint128 _collateral,
        uint128 _liquidity,
        ISilo.CollateralType _collateralType,
        bool _sameAsset
    ) internal returns (uint256 maxBorrow) {
        vm.assume(_liquidity > 0);
        vm.assume(_collateral > 0);

        emit log_named_string("_sameAsset", _sameAsset ? "yes" : "no");

        _depositForBorrow(_liquidity, depositor);
        _depositCollateral(_collateral, borrower, _sameAsset, _collateralType);

        maxBorrow = _maxBorrow1(_sameAsset);
        emit log_named_decimal_uint("maxBorrow", maxBorrow, 18);

        _assertWeCanNotBorrowAboveMax(maxBorrow, 1, _sameAsset);
        _assertMaxBorrowIsZeroAtTheEnd(_sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_collateralButNoLiquidity
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_maxBorrow_collateralButNoLiquidity_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 0);

        _deposit(_collateral, borrower);

        _assertMaxBorrowIsZeroAtTheEnd(TWO_ASSETS);
    }

    /*
    forge test -vv --ffi --mt test_debug_case
    */
    function test_debug_case_1() public {
        _debug_case(SAME_ASSET);
    }

    function test_debug_case_2() public {
        _debug_case(TWO_ASSETS);
    }

    function _debug_case(bool _sameAsset) private {
        _depositCollateral(1e18, borrower, _sameAsset);

        uint256 maxBorrow = _maxBorrow1(_sameAsset);
        emit log_named_uint("maxBorrow before", maxBorrow);
        emit log_named_uint("balance of silo1", token1.balanceOf(address(silo1)));

        if (_sameAsset) {
            assertGt(maxBorrow, 0, "for same asset collateral is liquidity");
        } else {
            assertEq(maxBorrow, 0, "no liquidity");
        }

        _depositForBorrow(1e18, address(2));

        maxBorrow = _maxBorrow1(_sameAsset);
        emit log_named_uint("maxBorrow after", maxBorrow);

        _borrow(maxBorrow, borrower, _sameAsset);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_withDebt_1_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withDebt_1_fuzz(uint128 _collateral, uint128 _liquidity) public {
        _maxBorrow_withDebt(_collateral, _liquidity, SAME_ASSET);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_withDebt_2_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withDebt_2_fuzz(
        uint128 _collateral,
        uint128 _liquidity
    ) public {
        // (uint128 _collateral, uint128 _liquidity) = (3672, 3669);
        _maxBorrow_withDebt(_collateral, _liquidity, TWO_ASSETS);
    }

    function _maxBorrow_withDebt(uint128 _collateral, uint128 _liquidity, bool _sameAsset) public {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _depositCollateral(_collateral, borrower, _sameAsset);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = _maxBorrow1(_sameAsset);

        uint256 firstBorrow = maxBorrow / 3;
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower, _sameAsset);

        // now we have debt

        maxBorrow = _maxBorrow1(_sameAsset);
        _assertWeCanNotBorrowAboveMax(maxBorrow, 1, _sameAsset);

        _assertMaxBorrowIsZeroAtTheEnd(2, _sameAsset);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_withInterest
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withInterest_1_fuzz(uint128 _collateral, uint128 _liquidity) public {
        _maxBorrow_withInterest(_collateral, _liquidity, SAME_ASSET);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_withInterest_2_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_maxBorrow_withInterest_2_fuzz(uint128 _collateral, uint128 _liquidity) public {
        _maxBorrow_withInterest(_collateral, _liquidity, TWO_ASSETS);
    }

    function _maxBorrow_withInterest(uint128 _collateral, uint128 _liquidity, bool _sameAsset) public {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _depositCollateral(_collateral, borrower, _sameAsset);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = _maxBorrow1(_sameAsset);

        uint256 firstBorrow = maxBorrow / 3;
        emit log_named_uint("firstBorrow", firstBorrow);
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower, _sameAsset);

        // now we have interest
        vm.warp(block.timestamp + 100 days);

        maxBorrow = _maxBorrow1(_sameAsset);
        emit log_named_uint("maxBorrow", maxBorrow);

        _assertWeCanNotBorrowAboveMax(maxBorrow, _sameAsset);

        _assertMaxBorrowIsZeroAtTheEnd(2, _sameAsset);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_repayWithInterest_2tokens_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 5000
    function test_maxBorrow_repayWithInterest_2tokens_fuzz(uint64 _collateral, uint128 _liquidity) public {
        _maxBorrow_repayWithInterest(_collateral, _liquidity, ISilo.CollateralType.Collateral, TWO_ASSETS);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_repayWithInterest_2tokens_protected_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 5000
    function test_maxBorrow_repayWithInterest_2tokens_protected_fuzz(uint64 _collateral, uint128 _liquidity) public {
        _maxBorrow_repayWithInterest(_collateral, _liquidity, ISilo.CollateralType.Protected, TWO_ASSETS);
    }

    function test_maxBorrow_repayWithInterest_1token_fuzz(
        uint64 _collateral,
        uint128 _liquidity
    ) public {
        // (uint64 _collateral, uint128 _liquidity) = (5, 1);
        _maxBorrow_repayWithInterest(_collateral, _liquidity, ISilo.CollateralType.Collateral, SAME_ASSET);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_repayWithInterest_1token_protected_fuzz
    */
    function test_maxBorrow_repayWithInterest_1token_protected_fuzz(
        uint64 _collateral,
        uint128 _liquidity
    ) public {
        _maxBorrow_repayWithInterest(_collateral, _liquidity, ISilo.CollateralType.Protected, SAME_ASSET);
    }

    function _maxBorrow_repayWithInterest(
        uint64 _collateral,
        uint128 _liquidity,
        ISilo.CollateralType _collateralType,
        bool _sameAsset
    ) internal {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _depositCollateral(_collateral, borrower, _sameAsset, _collateralType);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = _maxBorrow1(_sameAsset);

        uint256 firstBorrow = maxBorrow / 3;
        emit log_named_uint("firstBorrow", firstBorrow);
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower, _sameAsset);

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

        maxBorrow = _maxBorrow1(_sameAsset);
        assertGt(maxBorrow, 0, "we can borrow again after repay");

        _assertWeCanNotBorrowAboveMax(maxBorrow, _sameAsset);
        _assertMaxBorrowIsZeroAtTheEnd(29, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_maxOut
    // this is test from echidna findings
    */
    function test_echidna_maxBorrow_maxOut_2tokens() public {
        _maxBorrow_maxOut(TWO_ASSETS);
    }

    function test_maxBorrow_maxOut_1token() public {
        _maxBorrow_maxOut(SAME_ASSET);
    }

    function _maxBorrow_maxOut(bool _sameAsset) internal {
        address user0 = makeAddr("user0");
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        emit log("User 1 deposits 54901887191424375183106916902 assets into Silo 2");
        _depositCollateral(54901887191424375183106916902, user1, !_sameAsset);

        emit log("User 0 deposits 37778931862957161709569 assets into Silo 1");
        _deposit(37778931862957161709569, user0);

        emit log("User 2 mints 57553484963063775982514231325194206610732636 shares from Silo 2");

        _sameAsset ? token0.setOnDemand(true) : token1.setOnDemand(true);
        _mintCollateral(1, 57553484963063775982514231325194206610732636, user2, !_sameAsset);
        _sameAsset ? token0.setOnDemand(false) : token1.setOnDemand(false);

        emit log_named_uint("User 1 max borrow same asset on silo1", silo0.maxBorrowSameAsset(user1));
        emit log_named_uint("User 1 max borrow on silo2", silo1.maxBorrow(user1));

        emit log("User 1 borrows the maximum returned from maxBorrow from Silo 1");
        uint256 maxBorrow = _sameAsset ? silo0.maxBorrowSameAsset(user1) : silo0.maxBorrow(user1);
        vm.prank(user1);
        _sameAsset
            ? silo0.borrowSameAsset(maxBorrow, user1, user1)
            : silo0.borrow(maxBorrow, user1, user1);

        vm.warp(block.timestamp + 41);

        emit log("Timestamp is increased by 41 seconds");

        emit log("User 0 deposits type(uint128).max assets into Silo 1");
        _deposit(type(uint128).max, user0);

        uint256 liquidity = silo0.getLiquidity();
        emit log_named_uint("liquidity on the fly", liquidity);
        silo0.accrueInterest();
        assertEq(liquidity, silo0.getLiquidity());

        maxBorrow = _sameAsset ? silo0.maxBorrowSameAsset(user2) : silo0.maxBorrow(user2);
        emit log_named_uint("user2 maxBorrow", maxBorrow);

        emit log("User 2 attempts to borrow maxBorrow assets, it should NOT fail with AboveMaxLtv()");
        vm.prank(user2);
        _sameAsset
            ? silo0.borrowSameAsset(maxBorrow, user2, user2) // expect to pass
            : silo0.borrow(maxBorrow, user2, user2); // expect to pass
    }

    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow, bool _sameAsset) internal {
        _assertWeCanNotBorrowAboveMax(_maxBorrow, 1, _sameAsset);
    }

    /// @param _precision is needed because we count for precision error and we allow for 1 wei diff
    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow, uint256 _precision, bool _sameAsset) internal {
        emit log_named_uint("------- QA: _assertWeCanNotBorrowAboveMax +/-", _precision);

        uint256 toBorrow = _maxBorrow + _precision;

        uint256 liquidity = silo1.getLiquidity();

        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] liquidity", liquidity, 18);
        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax]  toBorrow", toBorrow, 18);

        vm.prank(borrower);
        (bool success, bytes memory data) = address(silo1).call(abi.encodeWithSelector(
            _sameAsset ? ISilo.borrow.selector : ISilo.borrowSameAsset.selector,
            toBorrow, borrower, borrower
        ));

        if (success) {
            revert("we expect tx to be reverted for _maxBorrow + _precision!");
        } else {
            bytes4 errorType = bytes4(data);

            bytes4 error1 = bytes4(keccak256(abi.encodePacked("NotEnoughLiquidity()")));
            bytes4 error2 = bytes4(keccak256(abi.encodePacked("AboveMaxLtv()")));

            if (errorType != error1 && errorType != error2) {
                revert("we need to revert with AboveMaxLtv or NotEnoughLiquidity");
                // AboveMaxLtv means we at the limit and max borrow returned valid estimation for our LTV
                // NotEnoughLiquidity means max borrow was cap by liquidity
            }
        }

        if (_maxBorrow > 0) {
            emit log_named_decimal_uint(
                "[_assertWeCanNotBorrowAboveMax] _maxBorrow > 0? YES, borrowing max", _maxBorrow, 18
            );

            liquidity = silo1.getLiquidity();

            emit log_named_decimal_uint(
                "[_assertWeCanNotBorrowAboveMax]                          liquidity", liquidity, 18
            );

            if (_maxBorrow > liquidity) revert("max borrow returns higher number than available liquidity");

            _borrow(_maxBorrow, borrower, _sameAsset);
        }
    }

    function _assertMaxBorrowIsZeroAtTheEnd(bool _sameAsset) internal {
        _assertMaxBorrowIsZeroAtTheEnd(0, _sameAsset);
    }

    function _assertMaxBorrowIsZeroAtTheEnd(uint256 _underestimatedBy, bool _sameAsset) internal {
        emit log_named_uint("================ _assertMaxBorrowIsZeroAtTheEnd ================ +/-", _underestimatedBy);

        uint256 maxBorrow = _maxBorrow1(_sameAsset);

        assertLe(
            maxBorrow,
            _underestimatedBy,
            string.concat("[_assertMaxBorrowIsZeroAtTheEnd] at this point max should return 0 +/-", _underestimatedBy.toString())
        );
    }

    function _maxBorrow1(bool _sameAsset) internal view returns (uint256 max) {
        return _sameAsset ? silo1.maxBorrowSameAsset(borrower) : silo1.maxBorrow(borrower);
    }
}
