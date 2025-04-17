// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

// solhint-disable func-name-mixedcase
/*
FOUNDRY_PROFILE=core_test forge test -vv --mc ShareDebtTokenNotInitializedTest
*/
contract ShareDebtTokenNotInitializedTest is Test {
    ShareDebtToken public immutable sToken;

    constructor() {
        sToken = ShareDebtToken(Clones.clone(address(new ShareDebtToken())));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vvv --mt test_sToken_noInit_silo
    */
    function test_sToken_noInit_silo() public view {
        assertEq(address(sToken.silo()), address(0));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vvv --mt test_sToken_noInit_mint_zero
    */
    function test_sToken_noInit_mint_zero() public {
        vm.expectRevert(IShareToken.OnlySilo.selector); // silo is 0
        sToken.mint(address(1), address(1), 1);

        // counterexample
        vm.prank(address(0));
        vm.expectRevert(IShareToken.ZeroTransfer.selector);
        sToken.mint(address(1), address(1), 0);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vvv --mt test_sToken_noInit_mint
    */
    function test_sToken_noInit_mint() public {
        vm.expectRevert(IShareToken.OnlySilo.selector); // silo is 0
        sToken.mint(address(1), address(1), 3);

        vm.expectRevert(Hook.InvalidTokenType.selector);
        vm.prank(address(0));
        sToken.mint(address(1), address(1), 3);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vvv --mt test_sToken_noInit_burn
    */
    function test_sToken_noInit_burn() public {
        vm.expectRevert(IShareToken.OnlySilo.selector); // silo is 0
        sToken.burn(address(1), address(1), 0);

        // counterexample
        vm.prank(address(0));
        vm.expectRevert(IShareToken.ZeroTransfer.selector);
        sToken.burn(address(1), address(1), 0);
    }
}
