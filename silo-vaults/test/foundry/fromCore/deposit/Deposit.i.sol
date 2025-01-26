// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";

import {VaultsLittleHelper} from "../_common/VaultsLittleHelper.sol";

/*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc DepositTest -vv
*/
contract DepositTest is VaultsLittleHelper {
    /*
    forge test -vv --ffi --mt test_deposit_revertsZeroAssets
    */
    function test_deposit_revertsZeroAssets() public {
        uint256 _assets;
        address depositor = makeAddr("Depositor");

        vm.expectRevert(ErrorsLib.InputZeroShares.selector);
        vault.deposit(_assets, depositor);
    }

    /*
    forge test -vv --ffi --mt test_deposit_totalAssets
    */
    function test_deposit_totalAssets() public {
        _deposit(123, makeAddr("Depositor"));

        assertEq(vault.totalAssets(), 123, "totalAssets match deposit");
    }
}
