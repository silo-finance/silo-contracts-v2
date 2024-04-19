// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISiloReentrancyGuard {
    function nonReentrantBefore(uint256 _callee) external;
    function nonReentrantAfter() external;
    function reentrancyGuardState() external view returns (uint256);
}