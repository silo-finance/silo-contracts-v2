// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./ABDKMath64x64.sol";
import "../../../contracts/lib/ExponentMath.sol";
import "../data-readers/ExponentMathTestData.sol";
import "../data-readers/ExponentAddTestData.sol";

/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract ExponentMathTest
*/
contract ExponentMathTest is Test {
    address public constant COLLATERAL = address(123);
    uint256 public constant ONE = 1e18;

    ExponentMathTestData immutable exponentMathTestData;
    ExponentAddTestData immutable exponentAddTestData;

    uint128[] normaliseUpCommonMantisas;
    uint128[] normaliseDownCommonMantisas;
    uint128[] commonMantisas;

    constructor() {
        exponentMathTestData = new ExponentMathTestData();
        exponentAddTestData = new ExponentAddTestData();
        normaliseUpCommonMantisas = _normaliseUpMantisas();
        normaliseDownCommonMantisas = _normaliseDownMantisas();
        commonMantisas = _commonMantisas();
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_base2_fuzz
    */
    function test_ExponentMath_base2_fuzz(uint256 _x) public {
        vm.assume(_x != 0);
        vm.assume(_x <= ExponentMath._MAX_SCALAR);

        uint256 e = ExponentMath.base2(_x);
        assertLe(2 ** e, _x);
        assertGe(2 ** (e+1), _x);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_base2_revert
    */
    function test_ExponentMath_base2_revert() public {
        vm.expectRevert(ExponentMath.SCALAR_OVERFLOW.selector);
        ExponentMath.base2(ExponentMath._MAX_SCALAR + 1);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_exp_abdk_gas
    */
    function test_ExponentMath_exp_abdk_gas() public {
        uint256 x = 0x7FFFFFFFFFFFFFFF;

        uint256 gasStart = gasleft();
        uint256 e = ExponentMath.base2(x);
        uint256 gasEnd = gasleft();

        emit log_named_uint("gas", gasStart - gasEnd);
        emit log_named_uint("e", e);
        assertEq(gasStart - gasEnd, 610, "gas");

        gasStart = gasleft();
        int128 x64 = ABDKMath64x64.fromUInt(x);
        uint256 gasStartE = gasleft();
        int128 e64 = ABDKMath64x64.log_2(x64);
        uint256 gasE = gasStartE - gasleft();
        uint64 e2 = ABDKMath64x64.toUInt(e64);
        gasEnd = gasleft();

        emit log_named_uint("gas", gasStart - gasEnd);
        emit log_named_uint("gasE", gasE);
        emit log_named_int("x64", x64);
        emit log_named_int("e64", e64);
        emit log_named_uint("e2", e2);

        assertEq(e, e2);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_exp_abdk_fuzz
    */
    function test_ExponentMath_exp_abdk_fuzz(uint256 _x) public {
        vm.assume(_x != 0);
        vm.assume(_x < 0x7FFFFFFFFFFFFFFF);

        uint256 e = ExponentMath.base2(_x);

        int128 x64 = ABDKMath64x64.fromUInt(_x);
        int128 e64 = ABDKMath64x64.log_2(x64);
        uint64 abdkE = ABDKMath64x64.toUInt(e64);

        assertEq(e, abdkE, "e == abdkE");
    }


    /*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_toExp_gas
    */
    function test_ExponentMath_toExp_gas() public {
        unchecked {
            ExponentMathTestData.TestData[] memory testDatas = exponentMathTestData.testData();

            uint256 gasSum;
            uint256 gasSum2;
            assertEq(testDatas.length, 8, "for proper gas check, update it when add more tests");

            for (uint i; i < testDatas.length; i++) {
                // emit log_named_uint("-------- i", i);
                ExponentMathTestData.TestData memory testData = testDatas[i];

                uint256 gasStart = gasleft();
                (uint64 m, uint64 e) = ExponentMath.toExp(testData.scalar);
                uint256 gasEnd = gasleft();

                uint256 gasStart2 = gasleft();
                ExponentMath.fromExp(m, e);
                uint256 gasEnd2 = gasleft();

                gasSum += (gasStart - gasEnd);
                gasSum2 += (gasStart2 - gasEnd2);

                _assertMantisa(m);
                _assertExpEq(m, e, testData.exp.m, testData.exp.e);
            }

            assertEq(gasSum / testDatas.length, 868, "avg gas for toExp");
            assertEq(gasSum2 / testDatas.length, 210, "avg gas for fromExp");
        }
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_toFromExp_fuzz
    */
    function test_ExponentMath_toFromExp_fuzz(uint256 _x) public {
        vm.assume(_x != 0);
        vm.assume(_x <= ExponentMath._MAX_SCALAR);

        (uint64 m, uint64 e) = ExponentMath.toExp(_x);
        _assertMantisa(m);

        emit log_named_uint("ExponentMath._MAX_SCALAR", ExponentMath._MAX_SCALAR);
        emit log_named_uint("m", m);
        emit log_named_uint("e", e);

        uint256 result = ExponentMath.fromExp(m, e);

        _assertScalarEq(result, _x);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normalise_one
    */
    function test_ExponentMath_normalise_one() public {
        (uint64 m, uint64 e) = ExponentMath.normaliseUp(1, 100);
        _assertMantisa(m);
        assertEq(m, 2 ** 59);
        assertEq(e, 100 - 59);

        (m, e) = ExponentMath.normaliseDown(1e18 ** 2, 0);
        _assertMantisa(m);
        assertEq(m, 1e18 ** 2 >> 60);
        assertEq(e, 60);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_mul_fuzz
    */
    function test_ExponentMath_mul_fuzz(uint256 _x, uint64 _multiplier) public {
        vm.assume(_multiplier != 0);
        vm.assume(_x != 0);
        vm.assume(_x <= ExponentMath._MAX_SCALAR / uint256(_multiplier));

        (uint64 m, uint64 e) = ExponentMath.toExp(_x);
        (uint64 resultM, uint64 resultE) = ExponentMath.mul(m, e, _multiplier);
        (uint64 expectM, uint64 expectE) = ExponentMath.toExp(_x * uint256(_multiplier));

        _assertExpEqualish(resultM, resultE, expectM, expectE);
        _assertScalarEq(ExponentMath.fromExp(resultM, resultE), _x * uint256(_multiplier));
        _assertMantisa(resultM);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_mul_gas
    */
    function test_ExponentMath_mul_gas() public {
        uint256 gasStart = gasleft();
        (uint64 m,) = ExponentMath.mul(75e16, 70, 123e18);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 1329, "mul gas");
        _assertMantisa(m);
    }

    /*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_add_sub
    */
    function test_ExponentMath_add_sub() public {
        unchecked {
            ExponentAddTestData.TestData[] memory testDatas = exponentAddTestData.testData();

            uint256 gasSum;
            uint256 gasSum2;

            for (uint i; i < testDatas.length; i++) {
                // emit log_named_uint("-------- i", i);
                ExponentAddTestData.TestData memory testData = testDatas[i];

                uint256 gasStart = gasleft();
                (uint64 sumM, uint64 sumE) = ExponentMath.add(testData.a.m, testData.a.e, testData.b.m, testData.b.e);
                uint256 gasEnd = gasleft();

                _assertExpEq(sumM, sumE, testData.sum.m, testData.sum.e);

                uint256 gasStart2 = gasleft();
                (uint64 subM, uint64 subE) = ExponentMath.sub(testData.sum.m, testData.sum.e, testData.b.m, testData.b.e);
                uint256 gasEnd2 = gasleft();

                _assertExpEqualish(subM, subE, testData.a.m, testData.a.e);

                gasSum += (gasStart - gasEnd);
                gasSum2 += (gasStart2 - gasEnd2);
            }

            assertEq(gasSum / testDatas.length, 556, "avg gas for ADD");
            assertEq(gasSum2 / testDatas.length, 668, "avg gas for SUB");
        }
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_add_gas
    */
    function test_ExponentMath_add_gas() public {
        uint256 gasSum;
        uint256 c = commonMantisas.length;

        for (uint i; i < c; i++) {
            uint64 mi = uint64(commonMantisas[i]);
            uint64 e1 = uint64(70 + i % 3);
            uint64 e2 = uint64(70 - i % 3);

            uint256 gasStart = gasleft();
            (uint64 m,) = ExponentMath.add(mi, e1, mi, e2);
            uint256 gasEnd = gasleft();

            gasSum += (gasStart - gasEnd);

            _assertMantisa(m);
        }

        assertEq(gasSum / c, 448, "avg gas for ADD");
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_zero
    */
    function test_ExponentMath_zero() public {
        vm.expectRevert(ExponentMath.ZERO.selector);
        ExponentMath.mul(55e16, 10, 0);

        vm.expectRevert(ExponentMath.ZERO.selector);
        ExponentMath.toExp(0);

        vm.expectRevert(ExponentMath.ZERO.selector);
        ExponentMath.base2(0);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normaliseUp_fuzz
    */
    function test_ExponentMath_normaliseUp_fuzz(uint64 _m) public {
        vm.assume(_m != 0);
        vm.assume(_m <= ExponentMath._PRECISION);

        (uint64 m,) = ExponentMath.normaliseUp(_m, type(uint64).max / 2);
        _assertMantisa(m);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normaliseDown_fuzz
    */
    function test_ExponentMath_normaliseDown_fuzz(uint64 _m) public {
        vm.assume(_m >= ExponentMath._MINIMAL_MANTISA);

        (uint64 m,) = ExponentMath.normaliseDown(_m, type(uint64).max / 2);
        _assertMantisa(m);
    }
    
    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normaliseDown_gas
    */
    function test_ExponentMath_normaliseDown_gas() public {
        uint256 gasSum;
        uint256 c = normaliseDownCommonMantisas.length;

        for (uint i; i < c; i++) {
            uint128 mi = normaliseDownCommonMantisas[i];
            uint256 gasStart = gasleft();
            (uint64 m,) = ExponentMath.normaliseDown(mi, 80);
            uint256 gasEnd = gasleft();

            gasSum += (gasStart - gasEnd);

            _assertMantisa(m);
        }

        assertEq(gasSum / c, 248, "avg gas for normaliseDown");
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normaliseUp_gas
    */
    function test_ExponentMath_normaliseUp_gas() public {
        uint128[] memory ms = new uint128[](6);
        ms[0] = ExponentMath._PRECISION; // max expected value
        ms[1] = (uint128(ExponentMath._MINIMAL_MANTISA) ** 2) / ExponentMath._PRECISION; // min expected value

        uint256 range = ms[0] - ms[1];
        ms[2] = uint128(ms[1] + range * 1 / 5);
        ms[3] = uint128(ms[1] + range * 2 / 5);
        ms[4] = uint128(ms[1] + range * 3 / 5);
        ms[5] = uint128(ms[1] + range * 4 / 5);

        uint256 gasSum;

        for (uint i; i < ms.length; i++) {
            uint128 mi = ms[i];
            uint256 gasStart = gasleft();
            (uint64 m,) = ExponentMath.normaliseUp(mi, 80);
            uint256 gasEnd = gasleft();

            gasSum += (gasStart - gasEnd);

            _assertMantisa(m);
        }

        assertEq(gasSum / ms.length, 218, "avg gas for normaliseUp");
    }

    function _assertExpEq(uint64 _m, uint64 _e, uint256 _scalar) internal {
        (uint64 m, uint64 e) = ExponentMath.toExp(_scalar);

        assertEq(m, _m, "[_assertExpEq] m differs");
        assertEq(e, _e, "[_assertExpEq] e differs");

        uint256 fromExp = ExponentMath.fromExp(_m, _e);
        uint256 diff = _scalar - fromExp;
        uint256 diffPercent = diff * 1e18 / _scalar;
        assertLe(diffPercent, 1e13, "[_assertExpEq] expect diff not more than 0.00001%");
    }

    function _assertScalarEq(uint256 _scalarA, uint256 _scalarB) internal {
        (uint256 diff, uint256 maxScalar) = _scalarA > _scalarB
            ? (_scalarA - _scalarB, _scalarA)
            : (_scalarB - _scalarA, _scalarB);

        uint256 diffPercent = diff * 1e18 / maxScalar;

        if (diffPercent > 1e13) {
            emit log_named_uint("_scalarA", _scalarA);
            emit log_named_uint("_scalarB", _scalarB);
        }

        assertLe(diffPercent, 1e13, "[_assertScalarEq] expect difference no more than 0.00001%");
    }

    function _assertExpEq(uint64 _m1, uint64 _e1, uint64 _m2, uint64 _e2) internal {
        assertEq(_m1, _m2, "[_assertExpEq] m differs");
        assertEq(_e1, _e2, "[_assertExpEq] e differs");
    }

    function _assertExpEqualish(uint64 _m1, uint64 _e1, uint64 _m2, uint64 _e2) internal {
        uint256 diff = _m1 > _m2 ? _m1 - _m2 : _m2 - _m1;

        uint256 maxDiff = 4;
        _printExp(_m1, _e1);
        _printExp(_m2, _e2);

        if (diff > maxDiff) {
            // why we adjusting? because we can have situations like:
            // {1000000000000000000, 0} vs {500000000000000000, 1}
            if (_e1 < _e2) {
                _printExp("normalising exp", _m1, _e1);

                uint64 eDiff = _e2 - _e1;
                _e1 += eDiff;
                _m1 >>= eDiff;
            } else {
                _printExp("normalising exp", _m2, _e2);

                uint64 eDiff = _e1 - _e2;
                _e2 += eDiff;
                _m2 >>= eDiff;
            }

            diff = _m1 > _m2 ? _m1 - _m2 : _m2 - _m1;
        }

        assertLe(diff, maxDiff, "[_assertExpEqualish] ~m differs");
        assertEq(_e1, _e2, "[_assertExpEqualish] e differs");
    }

    function _assertMantisa(uint64 _m) internal {
        assertGe(_m, 5e17, "[_assertMentisa] m >= 0.5");
        assertLe(_m, 1e18, "[_assertMentisa] m <= 1.0");
    }

    function _normaliseUpMantisas() internal pure returns (uint128[] memory) {
        uint128[] memory ms = new uint128[](6);
        ms[0] = ExponentMath._PRECISION; // max expected value
        ms[1] = (uint128(ExponentMath._MINIMAL_MANTISA) ** 2) / ExponentMath._PRECISION; // min expected value

        uint256 range = ms[0] - ms[1];
        ms[2] = uint128(ms[1] + range * 1 / 5);
        ms[3] = uint128(ms[1] + range * 2 / 5);
        ms[4] = uint128(ms[1] + range * 3 / 5);
        ms[5] = uint128(ms[1] + range * 4 / 5);

        return ms;
    }

    function _normaliseDownMantisas() internal pure returns (uint128[] memory) {
        uint128[] memory ms = new uint128[](6);
        ms[0] = ExponentMath._PRECISION * 2; // max expected value
        ms[1] = uint128(ExponentMath._MINIMAL_MANTISA) * 2; // min expected value

        uint256 range = ms[0] - ms[1];
        ms[2] = uint128(ms[1] + range * 1 / 5);
        ms[3] = uint128(ms[1] + range * 2 / 5);
        ms[4] = uint128(ms[1] + range * 3 / 5);
        ms[5] = uint128(ms[1] + range * 4 / 5);

        return ms;
    }

    function _commonMantisas() internal pure returns (uint64[] memory) {
        uint64[] memory ms = new uint64[](6);
        ms[0] = uint64(ExponentMath._PRECISION); // max expected value
        ms[1] = ExponentMath._MINIMAL_MANTISA; // min expected value

        uint64 range = ms[0] - ms[1];
        ms[2] = uint64(ms[1] + range * 1 / 5);
        ms[3] = uint64(ms[1] + range * 2 / 5);
        ms[4] = uint64(ms[1] + range * 3 / 5);
        ms[5] = uint64(ms[1] + range * 4 / 5);

        return ms;
    }

    function _printExp(string memory _prefix, uint64 _m, uint64 _e) internal view {
        console.log("[%s] {m: %s, e: %s}", _prefix, _m, _e);
    }

    function _printExp(uint64 _m, uint64 _e) internal view {
        console.log("{m: %s, e: %s}", _m, _e);
    }
}
