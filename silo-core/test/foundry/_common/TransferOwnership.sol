// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

abstract contract TransferOwnership is Test {
    function _test_transfer2StepOwnership(address _contract, address _currentOwner) internal returns (bool) {
        address newOwner = makeAddr("newOwner");

        vm.prank(_currentOwner);
        Ownable2StepUpgradeable(_contract).transferOwnership(newOwner);

        assertEq(
            _currentOwner,
            Ownable2StepUpgradeable(_contract).owner(),
            "owner should be dao before 2step is completed"
        );

        vm.prank(newOwner);
        Ownable2StepUpgradeable(_contract).acceptOwnership();

        assertEq(newOwner, Ownable2StepUpgradeable(_contract).owner(), "transfer ownership failed");

        return true;
    }
}
