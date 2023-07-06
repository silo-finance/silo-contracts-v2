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
                Exponent memory exp = ExponentMath.toExp(testData.scalar);
                uint256 gasEnd = gasleft();

                uint256 gasStart2 = gasleft();
                ExponentMath.fromExp(exp);
                uint256 gasEnd2 = gasleft();

                gasSum += (gasStart - gasEnd);
                gasSum2 += (gasStart2 - gasEnd2);

                _assertMentisa(exp);
                _assertExpEq(exp, testData.exp);
            }

            assertEq(gasSum / testDatas.length, 940, "avg gas for toExp");
            assertEq(gasSum2 / testDatas.length, 232, "avg gas for fromExp");
        }
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_toFromExp_fuzz
    */
    function test_ExponentMath_toFromExp_fuzz(uint256 _x) public {
        vm.assume(_x != 0);
        vm.assume(_x <= ExponentMath._MAX_SCALAR);

        Exponent memory exp = ExponentMath.toExp(_x);
        _assertMentisa(exp);

        emit log_named_uint("ExponentMath._MAX_SCALAR", ExponentMath._MAX_SCALAR);
        emit log_named_uint("e", exp.e);
        emit log_named_uint("m", exp.m);
        uint256 result = ExponentMath.fromExp(exp);

        _assertScalarEq(result, _x);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normalise_one
    */
    function test_ExponentMath_normalise_one() public {
        Exponent memory exp = ExponentMath.normaliseUp(1, 100);
        _assertMentisa(exp);
        assertEq(exp.m, 2 ** 59);
        assertEq(exp.e, 100 - 59);

        exp = ExponentMath.normaliseDown(1e18 ** 2, 0);
        _assertMentisa(exp);
        assertEq(exp.m, 1e18 ** 2 >> 60);
        assertEq(exp.e, 60);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_mul_fuzz
    */
    function test_ExponentMath_mul_fuzz(uint256 _x, uint64 _multiplier) public {
        vm.assume(_multiplier != 0);
        vm.assume(_x != 0);
        vm.assume(_x <= ExponentMath._MAX_SCALAR / uint256(_multiplier));

        Exponent memory result = ExponentMath.mul(ExponentMath.toExp(_x), _multiplier);

        emit log_named_uint("e", result.e);
        emit log_named_uint("m", result.m);

        _assertExpEqualish(result, ExponentMath.toExp(_x * uint256(_multiplier)));
        _assertScalarEq(ExponentMath.fromExp(result), _x * uint256(_multiplier));
        _assertMentisa(result);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_mul_gas
    */
    function test_ExponentMath_mul_gas() public {
        uint256 gasStart = gasleft();
        Exponent memory result = ExponentMath.mul(Exponent(75e16, 70), 123e18);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 1665, "mul gas");
        _assertMentisa(result);
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
                Exponent memory sum = ExponentMath.add(testData.a, testData.b);
                uint256 gasEnd = gasleft();

                _assertExpEq(sum, testData.sum);

                uint256 gasStart2 = gasleft();
                Exponent memory sub = ExponentMath.sub(testData.sum, testData.b);
                uint256 gasEnd2 = gasleft();

                _assertExpEqualish(sub, testData.a);

                gasSum += (gasStart - gasEnd);
                gasSum2 += (gasStart2 - gasEnd2);
            }

            assertEq(gasSum / testDatas.length, 742, "avg gas for ADD");
            assertEq(gasSum2 / testDatas.length, 833, "avg gas for SUB");
        }
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_add_gas
    */
    function test_ExponentMath_add_gas() public {
        uint256 gasSum;
        uint256 c = commonMantisas.length;

        for (uint i; i < c; i++) {
            uint64 m = uint64(commonMantisas[i]);
            uint64 e1 = uint64(70 + i % 3);
            uint64 e2 = uint64(70 - i % 3);

            uint256 gasStart = gasleft();
            Exponent memory exp = ExponentMath.add(Exponent(m, e1), Exponent(m, e2));
            uint256 gasEnd = gasleft();

            gasSum += (gasStart - gasEnd);

            _assertMentisa(exp);
        }

        assertEq(gasSum / c, 847, "avg gas for ADD");
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_zero
    */
    function test_ExponentMath_zero() public {
        vm.expectRevert(ExponentMath.ZERO.selector);
        ExponentMath.mul(Exponent(55e16, 10), 0);

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

        Exponent memory exp = ExponentMath.normaliseUp(_m, type(uint64).max / 2);
        _assertMentisa(exp);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normaliseDown_fuzz
    */
    function test_ExponentMath_normaliseDown_fuzz(uint64 _m) public {
        vm.assume(_m >= ExponentMath._MINIMAL_MANTISA);

        Exponent memory exp = ExponentMath.normaliseDown(_m, type(uint64).max / 2);
        _assertMentisa(exp);
    }
    
    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ExponentMath_normaliseDown_gas
    */
    function test_ExponentMath_normaliseDown_gas() public {
        uint256 gasSum;
        uint256 c = normaliseDownCommonMantisas.length;

        for (uint i; i < c; i++) {
            uint128 m = normaliseDownCommonMantisas[i];
            uint256 gasStart = gasleft();
            Exponent memory exp = ExponentMath.normaliseDown(m, 80);
            uint256 gasEnd = gasleft();

            gasSum += (gasStart - gasEnd);

            _assertMentisa(exp);
        }

        assertEq(gasSum / c, 369, "avg gas for normaliseDown");
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
            uint128 m = ms[i];
            uint256 gasStart = gasleft();
            Exponent memory exp = ExponentMath.normaliseUp(m, 80);
            uint256 gasEnd = gasleft();

            gasSum += (gasStart - gasEnd);

            _assertMentisa(exp);
        }

        assertEq(gasSum / ms.length, 346, "avg gas for normaliseUp");
    }

    function _assertExpEq(Exponent memory _exp, uint256 _scalar) internal {
        Exponent memory exp = ExponentMath.toExp(_scalar);

        assertEq(exp.m, _exp.m, "[_assertExpEq] exp.m differs");
        assertEq(exp.e, _exp.e, "[_assertExpEq] exp.e differs");

        uint256 fromExp = ExponentMath.fromExp(_exp);
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

    function _assertExpEq(Exponent memory _exp1, Exponent memory _exp2) internal {
        assertEq(_exp1.m, _exp2.m, "[_assertExpEq] exp.m differs");
        assertEq(_exp1.e, _exp2.e, "[_assertExpEq] exp.e differs");
    }

    function _assertExpEqualish(Exponent memory _exp1, Exponent memory _exp2) internal {
        Exponent memory exp1 = Exponent(_exp1.m, _exp1.e);
        Exponent memory exp2 = Exponent(_exp2.m, _exp2.e);

        (uint256 diff, bool firstHasLowerE) = exp1.m > exp2.m
            ? (exp1.m - exp2.m, true)
            : (exp2.m - exp1.m, false);

        uint256 maxDiff = 4;

        if (diff > maxDiff) {
            // why we adjusting? because we can have situations like:
            // {1000000000000000000, 0} vs {500000000000000000, 1}
            if (firstHasLowerE) {
                _printExp("normalising exp", exp1);

                uint64 eDiff = exp2.e - exp1.e;
                exp1.e += eDiff;
                exp1.m >>= eDiff;
            } else {
                _printExp("normalising exp", exp2);

                uint64 eDiff = exp1.e - exp2.e;
                exp2.e += eDiff;
                exp2.m >>= eDiff;
            }

            diff = exp1.m > exp2.m ? exp1.m - exp2.m : exp2.m - exp1.m;
        }

        assertLe(diff, maxDiff, "[_assertExpEqualish] ~exp.m differs");
        assertEq(exp1.e, exp2.e, "[_assertExpEqualish] exp.e differs");
    }

    function _assertMentisa(Exponent memory _exp) internal {
        assertGe(_exp.m, 5e17, "[_assertMentisa] m >= 0.5");
        assertLe(_exp.m, 1e18, "[_assertMentisa] m <= 1.0");
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

    function _printExp(string memory _prefix, Exponent memory _exp) internal view {
        console.log("[%s] {m: %s, e: %s}", _prefix, _exp.m, _exp.e);
    }

    function _printExp(Exponent memory _exp) internal view {
        console.log("{m: %s, e: %s}", _exp.m, _exp.e);
    }
}
