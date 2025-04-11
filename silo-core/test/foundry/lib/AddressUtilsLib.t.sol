// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {AddressUtilsLib} from "silo-core/contracts/lib/AddressUtilsLib.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc AddressUtilsLibTest
contract AddressUtilsLibTest is Test {

    // FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_fromHexString_invalidAddressString
    function test_fromHexString_invalidAddressString() public {
        vm.expectRevert(abi.encodeWithSelector(AddressUtilsLib.InvalidAddressString.selector));
        AddressUtilsLib.fromHexString("0xxx34567890123456789012345678901234567890");
    }

    // FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_fromHexString_success
    function test_fromHexString_success() public view {
        address converted = AddressUtilsLib.fromHexString(Strings.toHexString(address(this)));
        assertEq(converted, address(this), "invalid string conversion");
    }
}