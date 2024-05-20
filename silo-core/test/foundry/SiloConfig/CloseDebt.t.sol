// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
forge test -vv --ffi --mc CloseDebtTest
*/
contract CloseDebtTest is SiloLittleHelper, Test {
    address immutable borrower;
    ISiloConfig siloConfig;

    address protectedShareToken;
    address collateralShareToken;
    address debtShareToken;

    constructor() {
        borrower = makeAddr("borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();
        token0.setOnDemand(true);

        vm.prank(borrower);
        silo0.leverageSameAsset(10e18, 1e18, borrower, ISilo.CollateralType.Collateral);
        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo0));

        (,, ISiloConfig.DebtInfo memory debtInfo) = siloConfig.getConfigs(address(silo0), borrower, Hook.NONE);
        assertTrue(debtInfo.debtPresent, "debt is required for this test");
    }

    /*
    forge test -vv --ffi --mt test_closeDebt_sendingZeroOfOtherDebtDoesNotClosePosition
    */
    function test_closeDebt_sendingZeroOfOtherDebtDoesNotClosePosition() public {
        (,, address otherDebtShareToken) = siloConfig.getShareTokens(address(silo1));

        vm.prank(borrower);
        IShareToken(otherDebtShareToken).transfer(address(1), 0);

        (,, ISiloConfig.DebtInfo memory debtInfo) = siloConfig.getConfigs(address(silo0), borrower, 0);
        assertTrue(debtInfo.debtPresent, "debt must exist");
    }

    function test_closeDebt_sendingZeroOfDebtDoesNotClosePosition() public {
        vm.prank(borrower);
        IShareToken(debtShareToken).transfer(address(1), 0);

        (,, ISiloConfig.DebtInfo memory debtInfo) = siloConfig.getConfigs(address(silo0), borrower, 0);
        assertTrue(debtInfo.debtPresent, "debt must exist");
    }

    function test_closeDebt_sendingSomeOfDebtDoesNotClosePosition() public {
        address receiver = makeAddr("receiver");

        vm.prank(receiver);
        IERC20R(debtShareToken).setReceiveApproval(borrower, 2);

        vm.prank(borrower);
        IShareToken(debtShareToken).transfer(receiver, 1);

        (,, ISiloConfig.DebtInfo memory debtInfo) = siloConfig.getConfigs(address(silo0), borrower, 0);
        assertTrue(debtInfo.debtPresent, "debt must exist");
    }
}
