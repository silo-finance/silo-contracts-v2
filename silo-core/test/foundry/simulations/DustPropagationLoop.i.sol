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
    /// forge-config: core-test.fuzz.runs = 1000
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
        _dustPropagation_deposit_borrow(INIT_ASSETS, 1, 0, true);
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_deposit_borrow_noInterest_borrowers
    */
    function test__skip__dustPropagation_deposit_borrow_noInterest_borrowers() public {
        _dustPropagation_deposit_borrow(INIT_ASSETS, 3, 0, true);
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_deposit_borrow_withInterest_borrowers
    */
    function test__skip__dustPropagation_deposit_borrow_withInterest_borrowers_1token() public {
        _dustPropagation_deposit_borrow(INIT_ASSETS, 3, 60 * 60 * 24, true);
    }

    /*
    forge test -vv --ffi --mt test__skip__dustPropagation_deposit_borrow_withInterest_borrowers
    */
    function test__skip__dustPropagation_deposit_borrow_withInterest_borrowers_2tokens() public {
        _dustPropagation_deposit_borrow(INIT_ASSETS, 3, 60 * 60 * 24, false);
    }

    function _dustPropagation_deposit_borrow(
        uint256 _assets,
        uint8 _borrowers,
        uint24 _moveForwardSec,
        bool _sameAsset
    ) private {
        uint256 loop = 1000;
        vm.assume(_assets / loop > 10);

        address user1 = makeAddr("user1");

        for (uint256 i = 1; i < loop; i++) {
            _depositForBorrow(_assets / i, user1);

            for (uint256 b; b < _borrowers; b++) {
                address borrower = makeAddr(string.concat("borrower", string(abi.encodePacked(b))));
                address depositor = makeAddr(string.concat("depositor", string(abi.encodePacked(b))));

                if (_sameAsset) {
                    _depositCollateral(_assets * i, borrower, _sameAsset);
                } else {
                    _depositForBorrow(_assets * i, depositor);
                    _depositCollateral(_assets * i, borrower, _sameAsset); // deposit collateral to other silo
                }

                _borrow(_assets * i / 2, borrower, _sameAsset);
            }

            if (_moveForwardSec > 0) {
                vm.warp(block.timestamp + _moveForwardSec);
            }
        }

        for (uint256 b; b < _borrowers; b++) {
            address borrower = makeAddr(string.concat("borrower", string(abi.encodePacked(b))));
            address depositor = makeAddr(string.concat("depositor", string(abi.encodePacked(b))));

            uint256 debt = silo1.maxRepay(borrower);
            _repay(debt, borrower);

            ISilo collateralSilo = _sameAsset ? silo1 : silo0;
            uint256 maxShares = collateralSilo.maxRedeem(borrower);

            vm.prank(borrower);
            collateralSilo.redeem(maxShares, borrower, borrower);

            assertEq(collateralSilo.maxRepay(borrower), 0, string .concat("should be no debt", b.toString()));

            uint256 shares = silo1.maxRedeem(depositor);
            vm.prank(depositor);
            silo1.redeem(shares, depositor, depositor);
        }

        uint256 shares1 = silo1.maxRedeem(user1);
        vm.prank(user1);
        silo1.redeem(shares1, user1, user1);

        (uint192 daoAndDeployerFees, ) = silo0.siloData();

        if (daoAndDeployerFees != 0) {
            silo0.withdrawFees();
        }

        if (_moveForwardSec == 0) {
            assertEq(silo0.getLiquidity(), 0, "[silo0] generated dust");
            assertEq(silo0.getCollateralAssets(), 0, "[silo0] getCollateralAssets");
        } else {
            assertLe(silo0.getLiquidity(), 1, "[silo0] generated dust with interest");
            assertLe(silo0.getCollateralAssets(), 1, "[silo0] getCollateralAssets with interest");
        }

        assertLe(silo1.getLiquidity(), 0, "[silo1] silo1 was only for collateral, so no dust is expected");
        assertLe(silo1.getCollateralAssets(), 0, "[silo1] silo1 was only for collateral, so no dust is expected");
    }
}
