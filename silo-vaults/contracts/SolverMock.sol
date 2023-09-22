// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "./lib/SolverLib.sol";

contract SolverMock {
    function callSolver(
        uint256[] memory borrow,
        uint256[] memory deposit,
        uint256[] memory uopt,
        uint256[] memory ucrit,
        uint256 amountToDistribute
    ) public returns (uint256[] memory) {
        return SolverLib._solver(borrow, deposit, uopt, ucrit, amountToDistribute);
    }
}
