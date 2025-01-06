// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc UrdTest -vvv
*/
contract UrdTest is IntegrationTest {
    function testSetSkimRecipient(address newSkimRecipient) public {
        vm.assume(newSkimRecipient != SKIM_RECIPIENT);

        vm.expectEmit();
        emit EventsLib.SetSkimRecipient(newSkimRecipient);

        vm.prank(OWNER);
        vault.setSkimRecipient(newSkimRecipient);

        assertEq(vault.skimRecipient(), newSkimRecipient);
    }

    function testAlreadySetSkimRecipient() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setSkimRecipient(SKIM_RECIPIENT);
    }

    function testSetSkimRecipientNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.setSkimRecipient(address(0));
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testSkimNotLoanToken -vvv
    */
    function testSkimNotLoanToken(uint256 amount) public {
        collateralToken.mint(address(vault), amount);

        vm.expectEmit(address(vault));
        emit EventsLib.Skim(address(this), address(collateralToken), amount);
        vault.skim(address(collateralToken));
        uint256 vaultBalanceAfter = collateralToken.balanceOf(address(vault));

        assertEq(vaultBalanceAfter, 0, "vaultBalanceAfter");
        assertEq(collateralToken.balanceOf(SKIM_RECIPIENT), amount, "collateralToken.balanceOf(SKIM_RECIPIENT)");
    }

    function testSkimZeroAddress() public {
        vm.prank(OWNER);
        vault.setSkimRecipient(address(0));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        vault.skim(address(loanToken));
    }
}
