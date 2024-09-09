// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc RepayOverflowTest
*/
contract RepayOverflowTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_repay_overflowInterest
    */
    function test_repay_overflowInterest() public {
        address borrower = makeAddr("borrower");
        address borrower2 = makeAddr("borrower2");

        uint256 shares1 = _depositForBorrow(type(uint160).max, makeAddr("user1"));
        uint256 shares2 = _depositForBorrow(1, makeAddr("user2"));
        uint256 shares3 = _depositForBorrow(1e18, makeAddr("user3"));

        _depositCollateral(type(uint160).max, borrower, TWO_ASSETS);
        uint256 debtShares = _borrow(type(uint160).max / 100 * 75, borrower, TWO_ASSETS);

        _depositCollateral(type(uint160).max / 100 * 25 * 2, borrower2, TWO_ASSETS);
        uint256 debtShares2 = _borrow(type(uint160).max / 100 * 25, borrower2, TWO_ASSETS);

        uint256 ltvBefore = siloLens.getLtv(silo1, borrower);

        emit log_named_decimal_uint("LTV before", ltvBefore, 16);
        _printUtilization(silo1);
        vm.warp(1 days);
//        vm.warp(type(uint64).max);
//
        for (uint i;; i++) {
            silo1.accrueInterest();

            uint256 newLtv = siloLens.getLtv(silo1, borrower);

            if (ltvBefore != newLtv) {
                ltvBefore = newLtv;
                vm.warp(block.timestamp + 365 days);
                emit log_named_uint("years pass", i);
                _printUtilization(silo1);

            } else {
                emit log("INTEREST OVERFLOW");
                break;
            }
        }

        emit log("additional time should make no difference:");
        vm.warp(block.timestamp + 365 days);
        silo1.accrueInterest();
        _printUtilization(silo1);

        emit log_named_decimal_uint("LTV after", siloLens.getLtv(silo0, borrower), 16);
        _printUtilization(silo1);

        // looks like we can overflow on IRM even when we have overflow detection
        _repayShares(1325135298583788246851134488512065154111302330346460741, debtShares, borrower);
        _repayShares(441711766194596082283711496170688384703767443448820246, debtShares2, borrower2);

        emit log_named_decimal_uint("LTV repayed", siloLens.getLtv(silo1, borrower), 16);
        emit log_named_decimal_uint("LTV repayed2", siloLens.getLtv(silo1, borrower2), 16);

        uint256 withdraw1 = _withdraw(makeAddr("user1"), shares1);
        emit log_named_uint("deposit1", type(uint160).max);
        emit log_named_uint("withdraw1", withdraw1);

        uint256 withdraw2 = _withdraw(makeAddr("user2"), shares2);
        emit log_named_uint("deposit2", 1);
        emit log_named_uint("withdraw2", withdraw2);

        uint256 withdraw3 = _withdraw(makeAddr("user3"), shares3);
        emit log_named_uint("deposit3", 1e18);
        emit log_named_uint("withdraw3", withdraw3);
    }

    function _withdraw(address _user, uint256 _shares) private returns (uint256 assets) {
        vm.prank(_user);
        assets = silo1.redeem(_shares, _user, _user);
    }

    function _printUtilization(ISilo _silo) private {
        ISilo.UtilizationData memory data = _silo.utilizationData();

        emit log_named_decimal_uint("[UtilizationData] collateralAssets", data.collateralAssets, 18);
        emit log_named_decimal_uint("[UtilizationData] debtAssets", data.debtAssets, 18);
        emit log_named_uint("[UtilizationData] interestRateTimestamp", data.interestRateTimestamp);
    }
}
