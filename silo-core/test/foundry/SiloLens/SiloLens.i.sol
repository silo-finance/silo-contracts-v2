// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ShareTokenDecimalsPowLib} from "../_common/ShareTokenDecimalsPowLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloLensIntegrationTest
*/
contract SiloLensIntegrationTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using ShareTokenDecimalsPowLib for uint256;

    ISiloConfig siloConfig;

    address depositor = makeAddr("depositor");
    address borrower = makeAddr("borrower");

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi --mt test_siloLens_utilization_75 -vv
    */
    function test_siloLens_utilization_75() public {

        uint256 deposit0 = 33e18;
        uint256 deposit1 = 11e18;
        uint256 collateral = 11e18;

        _deposit(deposit0, depositor);
        assertTrue(siloLens.hasPosition(siloConfig, depositor), "hasPosition");
        assertTrue(siloLens.hasPosition(siloConfig, depositor), "depositor has position in silo0 but we checking whole market");

        _depositForBorrow(deposit1, depositor);

        assertTrue(siloLens.isSolvent(silo0, depositor), "depositor has no debt");
        assertEq(siloLens.liquidity(silo0), deposit0, "liquidity in silo0");
        assertEq(siloLens.liquidity(silo1), deposit1, "liquidity in silo1");
        assertEq(siloLens.getRawLiquidity(silo0), deposit0, "getRawLiquidity 0");
        assertEq(siloLens.getRawLiquidity(silo1), deposit1, "getRawLiquidity 1");

        _depositCollateral(collateral, borrower, TWO_ASSETS);

        assertFalse(siloLens.inDebt(siloConfig, borrower), "borrower has no debt");

        assertEq(siloLens.liquidity(silo0), deposit0 + collateral, "liquidity in silo0 before borrow");
        assertEq(siloLens.liquidity(silo1), deposit1, "liquidity in silo1 before borrow");
        assertEq(siloLens.getRawLiquidity(silo0), deposit0 + collateral, "getRawLiquidity 0 before borrow");
        assertEq(siloLens.getRawLiquidity(silo1), deposit1, "getRawLiquidity 1 before borrow");

        assertEq(siloLens.totalDeposits(silo1), deposit1, "totalDeposits before borrow");

        uint256 toBorrow = silo1.maxBorrow(borrower);
        _borrow(toBorrow, borrower);

        assertTrue(siloLens.isSolvent(silo1, borrower), "borrower is solvent @0");
        assertTrue(siloLens.isSolvent(silo1, borrower), "borrower is solvent @1");
        assertTrue(siloLens.inDebt(siloConfig, borrower), "borrower has debt now");

        assertTrue(siloLens.hasPosition(siloConfig, borrower), "borrower has position #0");
        assertTrue(siloLens.hasPosition(siloConfig, borrower), "borrower has position #1");

        assertEq(siloLens.getUserLTV(silo0, borrower), 0.75e18, "borrower LTV #0");
        assertEq(siloLens.getUserLTV(silo1, borrower), 0.75e18, "borrower LTV #1");

        assertEq(siloLens.getUtilization(silo0), 0, "getUtilization #0");
        assertEq(siloLens.getUtilization(silo1), 0.75e18, "getUtilization #1");

        assertEq(
            siloLens.calculateCollateralValue(siloConfig, borrower),
            collateral,
            "calculateCollateralValue (price is 1:1)"
        );

        assertEq(
            siloLens.calculateBorrowValue(siloConfig, borrower),
            toBorrow,
            "calculateBorrowValue (price is 1:1)"
        );

        assertEq(
            siloLens.collateralBalanceOfUnderlying(silo0, borrower),
            collateral,
            "collateralBalanceOfUnderlying after borrow"
        );

        assertEq(
            siloLens.debtBalanceOfUnderlying(silo0, borrower),
            0,
            "[debtBalanceOfUnderlying] no debt in silo0"
        );

        assertEq(
            siloLens.debtBalanceOfUnderlying(silo1, borrower),
            toBorrow,
            "collateralBalanceOfUnderlying"
        );

        assertEq(siloLens.totalDeposits(silo1), deposit1, "totalDeposits after borrow are the same");

        vm.warp(block.timestamp + 65 days);

        assertFalse(siloLens.isSolvent(silo0, borrower), "borrower is NOT solvent @0");
        assertFalse(siloLens.isSolvent(silo1, borrower), "borrower is NOT solvent @1");

        assertEq(
            siloLens.totalDeposits(silo1),
            deposit1,
            "totalDeposits after borrow + time are the same, because we reading storage"
        );

        assertGt(
            siloLens.totalDepositsWithInterest(silo1),
            deposit1,
            "totalDepositsWithInterest after borrow + time + interest"
        );

        assertEq(
            siloLens.totalBorrowAmount(silo1),
            toBorrow,
            "totalBorrowAmount = toBorrow (no interest)"
        );

        assertGt(
            siloLens.totalBorrowAmountWithInterest(silo1),
            toBorrow,
            "totalBorrowAmountWithInterest = toBorrow + interest on the fly"
        );

        assertEq(
            siloLens.borrowShare(silo1, borrower),
            toBorrow,
            "borrowShare = toBorrow  (no offset)"
        );

        assertEq(
            siloLens.totalBorrowShare(silo1),
            toBorrow,
            "totalBorrowShare = toBorrow  (no offset)"
        );

        assertEq(siloLens.liquidity(silo0), deposit0 + collateral, "liquidity in silo0 after borrow + time");

        assertLt(
            siloLens.liquidity(silo1),
            deposit1 - toBorrow,
            "liquidity in silo1 after borrow + time is less than deposit - borrow, because of interest"
        );

        assertEq(siloLens.getRawLiquidity(silo0), deposit0 + collateral, "getRawLiquidity 0 after borrow + time");
        assertEq(siloLens.getRawLiquidity(silo1), deposit1 - toBorrow, "getRawLiquidity 1 after borrow + time");

        assertEq(
            siloLens.collateralBalanceOfUnderlying(silo0, borrower),
            collateral,
            "collateralBalanceOfUnderlying"
        );

        assertGt(
            siloLens.debtBalanceOfUnderlying(silo1, borrower),
            toBorrow,
            "[debtBalanceOfUnderlying] with interest debt is higher"
        );

        silo1.accrueInterest();

        assertGt(
            siloLens.totalDeposits(silo1),
            deposit1,
            "totalDeposits after borrow + interest"
        );

        uint256 maxRepayBefore = silo1.maxRepay(borrower);
        assertEq(maxRepayBefore, 14.994397297218850137e18, "maxRepayBefore");

        vm.warp(block.timestamp + 300 days);

        uint256 maxRepayAfter = silo1.maxRepay(borrower);
        assertEq(maxRepayAfter, 1247.410613506809097866e18, "maxRepayAfter");

        assertTrue(siloLens.hasPosition(siloConfig, borrower), "hasPosition");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi --mt test_skip_siloLens_apy_utilization_fuzz -vv
    */
    function test_skip_siloLens_apy_utilization_fuzz(uint8 _utilization) public {
        vm.assume(_utilization > 0 && _utilization <= 50); // because `defaultAsset` IRM model is for 50%

        _siloLens_apy_utilization(uint256(_utilization) * 1e16);
    }

    function _siloLens_apy_utilization(uint256 _utilization) internal {
        uint256 deposit0 = 33e18;
        uint256 deposit1 = 11e18;
        uint256 collateral = 11e18;

        _deposit(deposit0, depositor);
        _depositForBorrow(deposit1, depositor);
        _depositCollateral(collateral, borrower, TWO_ASSETS);

        uint256 toBorrow = collateral * _utilization / 1e18;
        _borrow(toBorrow, borrower);

        assertEq(siloLens.getUtilization(silo0), 0, "getUtilization #0");
        assertEq(siloLens.getUtilization(silo1), _utilization, "getUtilization #1");

        uint256 borrowAPY = siloLens.getBorrowAPR(silo1);
        uint256 depositAPY = siloLens.getDepositAPR(silo1);

        uint256 borrowInterest = toBorrow * borrowAPY / 1e18;
        uint256 depositInterest = deposit1 * depositAPY / 1e18;

        vm.warp(block.timestamp + 365 days);

        _assertCloseTo(silo1.maxRepay(borrower), toBorrow + borrowInterest, "borrow APY");
        _assertCloseTo(silo1.convertToAssets(silo1.balanceOf(depositor)), deposit1 + depositInterest, "deposit APY");

        silo0.accrueInterest();
        silo1.accrueInterest();

        _assertCloseTo(silo1.maxRepay(borrower), toBorrow + borrowInterest, "borrow APY");
        _assertCloseTo(silo1.convertToAssets(silo1.balanceOf(depositor)), deposit1 + depositInterest, "deposit APY");
    }

    function _assertCloseTo(uint256 _a, uint256 _closeTo, string memory _msg) internal {
        uint256 diff = Math.max(_a, _closeTo) - Math.min(_a, _closeTo);
        uint256 deviation = diff * 1e18 / _closeTo;

        emit log_named_uint("      _a", _a);
        emit log_named_uint("_closeTo", _closeTo);
        assertLt(deviation, 0.005e18, string.concat(_msg, " (accepted diff 0.5%)"));
    }
}
