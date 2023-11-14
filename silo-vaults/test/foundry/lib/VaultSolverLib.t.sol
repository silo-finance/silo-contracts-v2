// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {VaultSolverLib, VaultSolverInput} from "silo-vaults/contracts/lib/VaultSolverLib.sol";

import "../data-readers/VaultSolverLibTestData.sol";
import {Assertions} from "../_common/Assertions.sol";


// forge test -vv --mc VaultSolverLibTest
contract VaultSolverLibTest is VaultSolverLibTestData, Assertions {
    /*
    forge test -vv --mt test_VaultSolver_empty
    */
    function test_VaultSolver_empty() public {
        uint256 amountToDistribute;
        uint256 numberOfBaskets;
        VaultSolverInput[] memory input;

        uint256[] memory results = VaultSolverLib.solver(input, amountToDistribute, numberOfBaskets);

        assertEq(results.length, 0);
    }

    /*
    forge test -vv --mt test_VaultSolver_zeros
    */
    function test_VaultSolver_zeros() public {
        uint256 amountToDistribute;
        uint256 numberOfBaskets;
        VaultSolverInput[] memory input = new VaultSolverInput[](1);

        uint256[] memory resutls = VaultSolverLib.solver(input, amountToDistribute, numberOfBaskets);

        assertEq(resutls[0], 0);
        assertEq(resutls.length, 1);
    }

    /*
    forge test -vv --mt test_VaultSolver_debug
    */
    function test_VaultSolver_debug() public {
        VaultSolverLibData[] memory data = _readDataFromJson();

        for(uint256 i; i < data.length; i++) {
            if (i != 1) continue;

            _print(data[i]);

            (
                uint256 amountToDistribute,
                uint256 numberOfBaskets,
                VaultSolverInput[] memory input
            ) = _parseTestData(data[i]);

            uint256 gasStart = gasleft();
            uint256[] memory resutls = VaultSolverLib.solver(input, amountToDistribute, numberOfBaskets);
            uint256 gasEnd = gasleft();

            assertEq(resutls.length, input.length, "result should return array with same size as input");

            for (uint256 j; j < resutls.length; j++) {
                uint256 precission = 1e3;

                assertRelativeCloseTo(
                    resutls[j],
                    data[i].data[j].expectedS,
                    precission,
                    string.concat("test case #", Strings.toString(i), " failed")
                );
            }

            assertEq(gasStart - gasEnd, 117653, "VaultSolverLib.solver gas");
        }
    }

    function _parseTestData(VaultSolverLibData memory _testData)
        internal
        pure
        returns(
            uint256 amountToDistribute,
            uint256 numberOfBaskets,
            VaultSolverInput[] memory input
        )
    {
        amountToDistribute = _testData.amountToDistribute;
        numberOfBaskets = _testData.numberOfBaskets;
        input = new VaultSolverInput[](_testData.data.length);

        for(uint256 i; i < _testData.data.length; i++) {
            input[i] = VaultSolverInput({
                borrow: _testData.data[i].borrow,
                deposit: _testData.data[i].deposit,
                ucrit: _testData.data[i].ucrit,
                uopt: _testData.data[i].uopt
            });
        }
    }
}
