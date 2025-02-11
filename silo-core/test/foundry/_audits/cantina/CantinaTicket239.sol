// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {CantinaTicket} from "./CantinaTicket.sol";

/*
    forge test -vv --ffi --mc CantinaTicket239
*/
contract CantinaTicket239 is CantinaTicket {
    function test_repay_early_accrue_interest_rate() public {
        address alice = makeAddr("Alice");
        address bob = makeAddr("Bob");
        uint128 assets = 1e18;

        // 1. Bob supplies tokens
        _depositForBorrow(assets, bob);
        _deposit(assets, bob);

        vm.warp(block.timestamp + 1 days);

        // 2: Alice supplies and borrows assets
        _createDebt(assets, alice);

        // 3: Bob accruing interest
        vm.warp(block.timestamp + 10 days);

        // 4: Alice repays all debt
        _repayShares(silo1.maxRepay(alice), silo1.maxRepayShares(alice), alice);
        assertEq(silo1.maxRepay(alice), 0, "no more debt");
        assertEq(siloLens.getLtv(silo1, alice), 0, "LTV 0");

        uint amountAfterRepay = silo1.getCollateralAssets();  // get collat amount with interest
        uint debtAfterRepay = silo1.getDebtAssets();

        // but interest rate keeps accruing for Bob
        vm.warp(block.timestamp + 100 days);

        assertEq(amountAfterRepay, silo1.getCollateralAssets(), "no interest on collateral");
        assertEq(debtAfterRepay, silo1.getDebtAssets(), "no interest on debt");
    }
}
