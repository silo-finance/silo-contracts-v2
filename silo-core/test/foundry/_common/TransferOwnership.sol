// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

abstract contract TransferOwnership is Test {
    function _test_transfer2StepOwnership(address _contract, address _currentOwner) internal returns (bool) {
        address newOwner = makeAddr("newOwner");

        vm.prank(_currentOwner);
        Ownable2Step(_contract).transferOwnership(newOwner);

        assertEq(
            _currentOwner,
            Ownable2Step(_contract).owner(),
            "owner should be dao before 2step is completed"
        );

        vm.prank(newOwner);
        Ownable2Step(_contract).acceptOwnership();

        assertEq(newOwner, Ownable2Step(_contract).owner(), "transfer ownership failed");

        return true;
    }
}
