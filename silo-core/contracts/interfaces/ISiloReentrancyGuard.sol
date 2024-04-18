// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISiloReentrancyGuard {
    function nonReentrantBefore() external;
    function nonReentrantAfter() external;
    function reentrancyGuardEntered() external view returns (bool);
}