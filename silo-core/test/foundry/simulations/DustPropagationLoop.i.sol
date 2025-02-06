// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc DustPropagationLoopTest

    conclusions:
    - multiple deposits does not generate dust
    - multiple borrowers does not generate dust if no interest
    - looks like dust is generated based on assets-shares relation
    - the highest dust in this simulation was 1 wei for 1000 users and 1 day gap between borrows
*/
contract DustPropagationLoopTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using Strings for uint256;

    uint256 constant INIT_ASSETS = 100_000e18;

    function setUp() public {
        _setUpLocalFixture();
        token0.setOnDemand(true);
        token1.setOnDemand(true);
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_just_deposit_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test__skip__dustPropagation_just_deposit_fuzz(uint128 _assets) public {
        uint256 loop = 1000;
        vm.assume(_assets / loop > 0);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        for (uint256 i = 1; i < loop; i++) {
            _deposit(_assets / i, user1);
            _deposit(_assets * i, user2);

            // withdraw 50%
            _redeem(silo0.maxRedeem(user2, ISilo.CollateralType.Collateral) / 2, user2);
        }

        _redeem(silo0.maxRedeem(user1, ISilo.CollateralType.Collateral), user1);
        _redeem(silo0.maxRedeem(user2, ISilo.CollateralType.Collateral), user2);

        assertEq(silo0.getLiquidity(), 0, "no dust if only deposit");
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_deposit_borrow_noInterest_oneBorrowers
    */
    function test__skip__dustPropagation_deposit_borrow_noInterest_oneBorrowers() public {
        _dustPropagation_deposit_borrow(INIT_ASSETS, 1, 0);
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_deposit_borrow_noInterest_borrowers
    */
    function test__skip__dustPropagation_deposit_borrow_noInterest_borrowers() public {
        _dustPropagation_deposit_borrow(INIT_ASSETS, 3, 0);
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_deposit_borrow_withInterest_borrowers
    */
    function test__skip__dustPropagation_deposit_borrow_withInterest_borrowers_1token() public {
        _dustPropagation_deposit_borrow(INIT_ASSETS, 3, 60 * 60 * 24);
    }

    /// @dev for delay of 1 day, this test can handle up to 3K borrowers, because each borrow make +1 day
    /// and we adding interest and then liquidity might be not enough to cover debt + interest and we can not
    /// borrow anymore
    /// @param _moveForwardSec do not use mre than a day, because interest will be too high and we can not borrow
    function _dustPropagation_deposit_borrow(
        uint256 _assets,
        uint16 _borrowers,
        uint24 _moveForwardSec
    ) private {
        for (uint256 b = 1; b <= _borrowers; b++) {
            address borrower = makeAddr(string.concat("borrower", b.toString()));
            address depositor = makeAddr(string.concat("depositor", b.toString()));

            _deposit(_assets / b, borrower);

            _depositForBorrow(_assets, depositor);

            _borrow(_assets / b / 2, borrower);

            if (_moveForwardSec > 0) {
                vm.warp(block.timestamp + _moveForwardSec);
            }
        }

        for (uint256 b = 1; b <= _borrowers; b++) {
            address borrower = makeAddr(string.concat("borrower", b.toString()));
            address depositor = makeAddr(string.concat("depositor", b.toString()));

            uint256 debt = silo1.maxRepay(borrower);
            _repay(debt, borrower);

            ISilo collateralSilo = silo0;
            uint256 maxShares = collateralSilo.maxRedeem(borrower);

            vm.prank(borrower);
            collateralSilo.redeem(maxShares, borrower, borrower);

            assertEq(collateralSilo.maxRepay(borrower), 0, string.concat("should be no debt", b.toString()));

            uint256 shares = silo1.maxRedeem(depositor);
            vm.prank(depositor);
            silo1.redeem(shares, depositor, depositor);
        }

        if (_moveForwardSec != 0) {
            silo1.withdrawFees();
        }

        if (_moveForwardSec == 0) {
            assertEq(silo1.getLiquidity(), 0, "[silo1] generated dust");
            assertEq(silo1.getCollateralAssets(), 0, "[silo1] getCollateralAssets");
        } else {
            assertLe(silo1.getLiquidity(), 1, "[silo1] generated dust with interest");
            assertLe(silo1.getCollateralAssets(), 1, "[silo1] getCollateralAssets with interest");
        }

        assertLe(silo0.getLiquidity(), 0, "silo0 was only for collateral, so no dust is expected");
        assertLe(silo0.getCollateralAssets(), 0, "silo0 was only for collateral, so no dust is expected");
    }
}
