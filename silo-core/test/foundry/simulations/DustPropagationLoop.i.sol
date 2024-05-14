// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc DustPropagationLoopTest

    conclusions:
    - multiple deposits does not generate dust
    - multiple borrowers does not generate dust if no interest,
      that means dust is generated based on assets-shares relation?
*/
contract DustPropagationLoopTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using Strings for uint256;

    function setUp() public {
        _setUpLocalFixture();
        token0.setOnDemand(true);
    }

    /*
    forge test -vv --ffi --mt test_dustPropagation_just_deposit
    */
    function test_dustPropagation_just_deposit(uint128 _assets) public {
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
    forge test -vv --ffi --mt test_dustPropagation_deposit_borrow_noInterest_oneBorrower_fuzz
    */
    function test_dustPropagation_deposit_borrow_noInterest_oneBorrower_fuzz(
//        uint128 _assets
    ) public {
        uint128 _assets =11000;
        _dustPropagation_deposit_borrow(_assets, 1, 0);
    }

    /*
    forge test -vv --ffi --mt test_dustPropagation_deposit_borrow_withInterest_borrowers_fuzz
    */
    function test_dustPropagation_deposit_borrow_withInterest_borrowers_fuzz(
        uint128 _assets
    ) public {
        _dustPropagation_deposit_borrow(_assets, 3, 60);
    }

    /*
    forge test -vv --ffi --mt test_dustPropagation_deposit_borrow_noInterest_borrowers_fuzz
    */
    function test_dustPropagation_deposit_borrow_noInterest_borrowers_fuzz(
        uint128 _assets
    ) public {
        _dustPropagation_deposit_borrow(_assets, 3, 0);
    }

    function _dustPropagation_deposit_borrow(
        uint128 _assets,
        uint8 _borrowers,
        uint8 _moveForwardSec
    ) private {
        uint256 loop = 1000;
        bool sameAsset = true;
        vm.assume(_assets / loop > 10);

        address user1 = makeAddr("user1");

        for (uint256 i = 1; i < loop; i++) {
            emit log_named_string("#i deposit", i.toString());

            _deposit(_assets / i, user1);

            for (uint256 b; b < _borrowers; b++) {
                emit log_named_string("borrow", string.concat(i.toString(), "/", b.toString()));

                address borrower = makeAddr(string.concat("borrower", string(abi.encodePacked(b))));

                _deposit(_assets * i, borrower);

                vm.prank(borrower);
                silo0.borrow(_assets / 2, borrower, borrower, sameAsset);
            }

            if (_moveForwardSec > 0) {
                vm.warp(block.timestamp + _moveForwardSec);
            }
        }

        for (uint256 b; b < _borrowers; b++) {
            emit log_named_string("repay", b.toString());

            address borrower = makeAddr(string.concat("borrower", string(abi.encodePacked(b))));

            uint256 debt = silo0.maxRepay(borrower);
            vm.prank(borrower);
            silo0.repay(debt, borrower);

            _redeem(silo0.maxRedeem(borrower, ISilo.CollateralType.Collateral), borrower);
            assertEq(silo0.maxRepay(borrower), 0, string .concat("should be no debt", b.toString()));
        }

        emit log("final withdraw");

        _redeem(silo0.maxRedeem(user1, ISilo.CollateralType.Collateral), user1);
        emit log("withdraw feeds");

        (uint192 daoAndDeployerFees, ) = silo0.siloData();

        if (daoAndDeployerFees != 0) {
            silo0.withdrawFees();
        }

        if (_moveForwardSec == 0) {
            assertEq(silo0.getLiquidity(), 0, "generated dust");
            assertEq(silo0.getCollateralAssets(), 0, "getCollateralAssets");
        } else {
            assertLe(silo0.getLiquidity(), 0, "generated dust with interest");
            assertLe(silo0.getCollateralAssets(), 0, "getCollateralAssets with interest");
        }
    }
}
