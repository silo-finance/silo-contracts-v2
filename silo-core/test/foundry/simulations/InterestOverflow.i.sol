// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc InterestOverflowTest

    this test checks scenario, when we overflow interest, in that case we should be able to repay and exit silo
*/
contract InterestOverflowTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_interestOverflow
    */
    function test_interestOverflow() public {
        address borrower = makeAddr("borrower");
        address borrower2 = makeAddr("borrower2");

        uint256 shares1 = _depositForBorrow(type(uint160).max, makeAddr("user1"));
        uint256 shares2 = _depositForBorrow(1, makeAddr("user2"));
        uint256 shares3 = _depositForBorrow(1e18, makeAddr("user3"));

        _depositCollateral(type(uint160).max, borrower, TWO_ASSETS);
        uint256 debtShares = _borrow(type(uint160).max / 100 * 75, borrower, TWO_ASSETS);

        _depositCollateral(type(uint160).max / 100 * 25 * 2, borrower2, TWO_ASSETS);
        uint256 debtShares2 = _borrow(type(uint160).max / 100 * 25, borrower2, TWO_ASSETS);

        // now move into future until we overflow interest

        uint256 ltvBefore = siloLens.getLtv(silo1, borrower);

        emit log_named_decimal_uint("LTV before", ltvBefore, 16);
        _printUtilization(silo1);
        vm.warp(1 days);

        for (uint i;; i++) {
            silo1.accrueInterest(); // TODO why when this is off, test fail?
            // looks like when I acrue interest more often, then interest are higner
            // eg 4,9M% vs 90M%

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

        uint256 dust = silo1.convertToAssets(1);

        { // too deep
            // even when overflow, we can deposit
            // +2 because of rounding UP on convertToAssets and mint
            _mintForBorrow(2 * dust + 2, 2, makeAddr("user4"));

            // this repay covers interest + 1 share of assets
            _repay(441711400819186749557981945249480204633012529463871054 + dust, borrower);

            (uint daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();
            emit log_named_decimal_uint("daoAndDeployerRevenue", daoAndDeployerRevenue, 18);

            assertEq(silo1.getLiquidity(), dust, "even with huge repay, we cover interest first");
        }

        // liquidity should allow to withdraw 1 share
        uint256 withdraw2 = _withdrawAndCheck(makeAddr("user2"), 1, shares2);

        assertEq(silo1.getLiquidity(), 0, "it was enough only for redeem 1 share");

        _repay(silo1.maxRepay(borrower), borrower);
        _repay(silo1.maxRepay(borrower2), borrower2);

        _withdrawAndCheck(makeAddr("user1"), type(uint160).max, shares1);

        uint256 withdraw3 = _withdrawAndCheck(makeAddr("user3"), 1e18, shares3);

        _withdrawAndCheck(makeAddr("user4"), 0, 2);

        {
            (uint daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();
            assertEq(token1.balanceOf(address(silo1)), daoAndDeployerRevenue + dust, "got balance for fees");
            silo1.withdrawFees();
            assertEq(token1.balanceOf(address(silo1)), dust, "dust left");
        }

        assertEq(_printUtilization(silo1).collateralAssets, dust, "collateral dust left");
        assertEq(withdraw2, dust, "dust is an amount of 1 share (rounding)");

        {
            assertEq(0, siloLens.getLtv(silo1, borrower), "LTV repayed");
            assertEq(0, siloLens.getLtv(silo1, borrower2), "LTV repayed2");
        }
    }

    function _redeemAll(address _user, uint256 _shares) private returns (uint256 assets) {
        vm.prank(_user);
        assets = silo1.redeem(_shares, _user, _user);
    }

    function _printUtilization(ISilo _silo) private returns (ISilo.UtilizationData memory data) {
        data = _silo.utilizationData();

        emit log_named_decimal_uint("[UtilizationData] collateralAssets", data.collateralAssets, 18);
        emit log_named_decimal_uint("[UtilizationData] debtAssets", data.debtAssets, 18);
        emit log_named_uint("[UtilizationData] interestRateTimestamp", data.interestRateTimestamp);
    }

    function _withdrawAndCheck(address _user, uint256 _deposited, uint256 _shares)
        private
        returns (uint256 withdrawn)
    {
        emit log_named_address("withdraw checks for", _user);

        withdrawn = _redeemAll(_user, _shares);
        emit log_named_uint("deposit", _deposited);
        emit log_named_uint("withdraw", withdrawn);

        if (_deposited != 0) {
            assertLt(_deposited, withdrawn, "user should earn");
        }

        assertEq(silo1.maxWithdraw(_user), 0, "max");
    }
}
