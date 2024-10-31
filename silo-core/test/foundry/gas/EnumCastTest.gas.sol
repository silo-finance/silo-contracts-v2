// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract EnumCastGasTest is Test {
    uint256 constant A = 1;
    uint256 constant B = 2;
    uint256 constant C = 3;

    enum SomeType1 {
        a,
        b
    }

    enum SomeType2 {
        a,
        b,
        c
    }

    mapping(SomeType2 => uint256) public someType2Map;
    mapping(uint8 => uint256) public uint8Map;
    mapping(uint256 => uint256) public uint256Map;

    /*
    forge test -vv --mt test_enumCast
    */
    function test_gas_enumCast() public {
        SomeType1 t1 = SomeType1.b;
        SomeType2 t2;
        uint8 t3;
        uint256 t4;
        uint256 data;

        uint256 gasStart = gasleft();
        t2 = SomeType2(uint8(t1));
        data = someType2Map[t2];
        uint256 gasEnd = gasleft();

        emit log_named_uint("t2 = SomeType2(uint8(t1))", gasStart - gasEnd);
        emit log_named_uint("data", data);

        gasStart = gasleft();
        t3 = uint8(t1);
        data = uint8Map[t3];
        gasEnd = gasleft();

        emit log_named_uint("t3 = uint8(t1)", gasStart - gasEnd);
        emit log_named_uint("data", data);

        gasStart = gasleft();
        t4 = uint256(t1);
        data = uint256Map[t4];
        gasEnd = gasleft();

        emit log_named_uint("t4 = uint256(t1)", gasStart - gasEnd);
        emit log_named_uint("data", data);
    }

    /*
    forge test -vv --mt test_enumCastInvalid
    */
    function test_enumCastInvalid() public {
        vm.expectRevert();
        _acceptUintReturnEnum(4);
    }

    function _acceptUintReturnEnum(uint256 _enum) internal pure returns(SomeType2) {
        return SomeType2(_enum);
    }
}
