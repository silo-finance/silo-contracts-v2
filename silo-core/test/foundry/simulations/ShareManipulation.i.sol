// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    1. sergiey example is based on 70day period
    2. depositing and withdrawing does not change share/assets ration (I was not able to do that)

*/
contract ShareManipulationTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_collateral_ratio --gas-limit 40000000000

    in this test I try to break 1wei:1we ratio and I can not with reasonable amount of assets

    we need time to increasing ratio of asset:shares

    */
    function test_collateral_ratio() public {
        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");
        address depositor2 = makeAddr("depositor2");
        address depositor3 = makeAddr("depositor3");

        _depositCollateral(1e18, borrower, TWO_ASSETS);
        _depositForBorrow(1e18, depositor);
        _borrow(0.75e18, borrower);

        uint256 precision = 1e18;
        // changing offset 1 -> 10 does not change much, it's basically higher precision, but numbers are the same.
        uint256 offset = 10 ** 0;

        // the higher number you check the faster we get result
        while(silo1.convertToAssets(precision * offset) == precision) {
            vm.warp(block.timestamp + 1);
        }

        emit log_named_uint("DIFF", silo1.convertToAssets(precision * offset));
        emit log_named_uint("DIFF", precision);
        emit log_named_decimal_uint("repay:", silo1.maxRepay(borrower), 18);
        emit log_named_uint("time:", block.timestamp);

        _printCollateralRatio(offset);

        uint256 ratioBefore = silo1.convertToAssets(precision * offset);
        uint256 moneySpend;
        uint256 _initial = 1e10; // changing initial amount does not affect ratio

        // so we can  max withdraw
        _depositForBorrow(0.9e18, depositor3);

        uint256 withdrawBefore = silo1.maxWithdraw(depositor);
        uint256 repayBefore = silo1.maxRepay(borrower);

        emit log_named_decimal_uint("maxWithdraw(depositor)", withdrawBefore, 18);
        emit log_named_decimal_uint("maxRepay(borrower)", repayBefore, 18);

        for(uint256 i; i < 150_000; i++) {
            // time helps increase ratio because there are interests involve
            // if attacker will wait 1sec between iterations, attack will take ~2days
            // HOWEVER: with time ratio grows MOSTLY because of interest, not the tx
//            vm.warp(block.timestamp + 1);

            // emit log_named_uint("#i", i);
            // emit log_named_decimal_uint("_initial", _initial, 18);

            uint256 depositAmount = (_initial % 10_000e18);

            _depositForBorrow(depositAmount, depositor2);
            // by leaving 1 wei you can change ratio by 1 per iteration
            // BUT you paying for it!
            _withdrawFromBorrow(depositAmount - 1, depositor2);
            moneySpend += (depositAmount - depositAmount + 1);

            _initial = silo1.getCollateralAssets();
        }

        emit log_named_uint("ratioBefore", ratioBefore);

        uint256 ratioDiff = silo1.convertToAssets(precision * offset) - ratioBefore;
        emit log_named_decimal_uint("ratio increased by", ratioDiff, 18);
        emit log_named_decimal_uint("moneySpend", moneySpend, 18);

        emit log_named_decimal_uint("maxRepay(borrower)", repayBefore, 18);
        emit log_named_decimal_uint("maxRepay(borrower)", silo1.maxRepay(borrower), 18);

        _repay(silo1.maxRepay(borrower), borrower);
        _printCollateralRatio(offset);

        // depositor2 was doing attack and he lost, he left 150K wei but he can withdraw only 78K wei after attack
        emit log_named_decimal_uint("maxWithdraw(depositor2)", silo1.maxWithdraw(depositor2), 18);
        emit log_named_decimal_uint("maxWithdraw(depositor3)", silo1.maxWithdraw(depositor3), 18);

        emit log_named_decimal_uint("maxWithdraw(depositor)", silo1.maxWithdraw(depositor), 18);
        emit log_named_decimal_uint("maxWithdraw(depositor) diff", silo1.maxWithdraw(depositor) - withdrawBefore, 18);
    }
    
    function _printBorrowRatio() internal {
        emit log_named_uint("1 share =", silo1.previewBorrowShares(1));
    }

    function _printCollateralRatio(uint256 _offset) internal {
        emit log_named_uint("[silo1] time", block.timestamp);
        emit log_named_uint("[silo1] getCollateralAssets", silo1.getCollateralAssets());
        emit log_named_uint("[silo1] 1 collateral share =", silo1.convertToAssets(1));
        emit log_named_uint("[silo1] 1e18 collateral share =", silo1.convertToAssets(1e18 * _offset));
    }
}
