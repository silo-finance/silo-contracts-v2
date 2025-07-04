// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOwnableLike {
    function acceptOwnership() external;
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}
