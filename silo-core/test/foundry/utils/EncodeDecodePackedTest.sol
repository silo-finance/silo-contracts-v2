// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract EncodeDecodePackedTest is Test {
    uint256 constant PACKED_ADDRESS_LENGTH = 20;
    uint256 constant PACKED_UINT24_LENGTH = 3;
    uint256 constant PACKED_BOOL_LENGTH = 1;
    uint256 constant PACKED_FULL_LENGTH = 32;

    /*
    forge test -vv --mt test_encodePacked_decodePacked
    */
    function test_encodePacked_decodePacked() public pure {
        address a = address(0xa);
        address b = address(0xb);
        uint256 c = 0xc;
        uint24 d = 0xd;
        bool e = true;
        address f = address(0xf);

        bytes memory packed = abi.encodePacked(a, b, c, d, e, f);

        (
            address aa,
            address bb,
            uint256 cc,
            uint24 dd,
            bool ee,
            address ff
        ) = decodePacked(packed);

        assertEq(a, aa, "a");
        assertEq(b, bb, "b");
        assertEq(c, cc, "c");
        assertEq(d, dd, "d");
        assertEq(e, ee, "e");
        assertEq(f, ff, "f");
    }

    function decodePacked(bytes memory packed)
        internal
        pure
        returns (address a, address b, uint256 c, uint24 d, bool e, address f)
    {
        assembly {
            let pointer := PACKED_ADDRESS_LENGTH
            a := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            b := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            c := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_UINT24_LENGTH)
            d := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_BOOL_LENGTH)
            e := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            f := mload(add(packed, pointer))
        }
    }
}
