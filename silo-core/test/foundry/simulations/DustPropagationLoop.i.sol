// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc LiquidationCall1TokenTest
*/
contract DustPropagationLoopTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
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
    forge test -vv --ffi --mt test_dustPropagation_deposit_borrow_noInterest
    */
    function test_dustPropagation_deposit_borrow_noInterest(
//        uint128 _assets
    ) public {
        uint128 _assets = 11000;

        uint256 loop = 1000;
        bool sameAsset = true;
        vm.assume(_assets / loop > 10);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        for (uint256 i = 1; i < loop; i++) {
            _deposit(_assets / i, user1);
            _deposit(_assets * i, user2);

            vm.prank(user2);
            silo0.borrow(_assets / 2, user2, user2, sameAsset);
        }

        uint256 debt = silo0.maxRepay(user2);
        vm.prank(user2);
        silo1.repay(debt, user2);

        _redeem(silo0.maxRedeem(user1, ISilo.CollateralType.Collateral), user1);
        _redeem(silo0.maxRedeem(user2, ISilo.CollateralType.Collateral), user2);

        assertEq(silo0.getLiquidity(), 0, "generated dust");
    }
}
