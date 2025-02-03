// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISiloHandler {
    function accrueInterest(uint8 i) external;
}
