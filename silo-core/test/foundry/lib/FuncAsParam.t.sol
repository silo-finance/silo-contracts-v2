// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

library TestLib {
    function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a + _b;
    }

    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a - _b;
    }
}


// forge test -vv --mc FuncAsParamTest
contract FuncAsParamTest is Test {
    // just to makes sure this is not consume more than a flag
    function test_function_as_param() public {
        uint256 gasStart = gasleft();
        _operation(100, 50, true);
        uint256 gasEnd = gasleft();

        emit log_named_uint("gas with flag", gasStart - gasEnd);


        gasStart = gasleft();
        _operation(100, 50, TestLib.add);
        gasEnd = gasleft();

        emit log_named_uint("gas with f", gasStart - gasEnd);
        // gas with flag: 203
        // gas with f: 189
    }

    function _operation(uint256 _a, uint256 _b, function(uint256, uint256) pure returns (uint256) _f)
        private
        pure
        returns (uint256)
    {
        return _f(_a, _b);
    }

    function _operation(uint256 _a, uint256 _b, bool _add) private pure returns (uint256) {
        return _add ? TestLib.add(_a, _b) : TestLib.sub(_a, _b);
    }
}
