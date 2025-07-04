// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IGnosisSafeLike {
    function getOwners() external view returns (address[] memory);
}
