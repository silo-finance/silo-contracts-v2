// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {VaultsLittleHelper} from "../../_common/VaultsLittleHelper.sol";
import {CAP} from "../../../helpers/BaseTest.sol";

/*
    FOUNDRY_PROFILE=vaults_tests forge test -vv --ffi --mc MaxDepositTest
*/
contract MaxDepositTest is VaultsLittleHelper {
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;
    uint256 internal constant _IDLE_CAP = type(uint184).max;

    /*
    FOUNDRY_PROFILE=vaults_tests forge test -vv --ffi --mt test_maxDeposit1
    */
    function test_maxDeposit1() public view {
        assertEq(
            vault.maxDeposit(address(1)),
            CAP + _IDLE_CAP,
            "ERC4626 expect to return summary CAP for all markets"
        );
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test -vv --ffi --mt test_maxDeposit_withDeposit
    */
    function test_maxDeposit_withDeposit() public {
        uint256 deposit = 123;

        _deposit(deposit, address(1));

        assertEq(
            vault.maxDeposit(address(1)),
            CAP + _IDLE_CAP - deposit,
            "ERC4626 expect to return summary CAP for all markets - deposit"
        );
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_maxDeposit_takesIntoAccountAccruedInterest --ffi -vv
    */
    /// forge-config: vaults_tests.fuzz.runs = 1000
    function test_maxDeposit_takesIntoAccountAccruedInterest_fuzz(
        uint128 _depositAmount, uint128 _aboveDeposit, uint8 _days
    ) public {
        vm.assume(_depositAmount > 1e18);
        vm.assume(_aboveDeposit > 1e18);
        vm.assume(_days > 1 && _days <= 10);

        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        address anyAddress = makeAddr("AnyAddress");
        uint256 cap = uint256(_depositAmount) + uint256(_aboveDeposit);

        // configuring supply queue and cap
        _setOneMarketToSupplyQueue(allMarkets[0]);
        _setCap(allMarkets[0], cap);

        // depositing into the SiloVault
        _deposit(_depositAmount, depositor);

        // Validating the max deposit after deposit (no interest yet)
        uint256 maxDepositAfterDeposit = vault.maxDeposit(anyAddress);
        uint256 totalAssetsAfterDeposit = vault.totalAssets();

        assertEq(maxDepositAfterDeposit, cap - _depositAmount, "Invalid max deposit after deposit");

        // creating a debt to accrue interest
        ISilo market = ISilo(address(allMarkets[0]));
        ISilo collateralMarket = ISilo(address(collateralMarkets[market]));

        vm.prank(borrower);
        collateralMarket.deposit(_depositAmount, borrower, ISilo.CollateralType.Collateral);

        vm.prank(borrower);
        market.borrow(_depositAmount / 2, borrower, borrower);

        // move time forward to accrue interest
        vm.warp(block.timestamp + _days * 1 days);

        // getting the max deposit after interest
        uint256 maxDepositWithInterest = vault.maxDeposit(anyAddress);
        uint256 totalAssetsAfterInterest = vault.totalAssets();

        uint256 accruedInterest = totalAssetsAfterInterest - totalAssetsAfterDeposit;

        assertNotEq(accruedInterest, 0, "Accrued interest should be greater than 0");

        assertEq(
            maxDepositWithInterest, // max deposit should subtract the accrued interest
            maxDepositAfterDeposit > accruedInterest ? maxDepositAfterDeposit - accruedInterest : 0,
            "Invalid max deposit after interest"
        );
    }
}
