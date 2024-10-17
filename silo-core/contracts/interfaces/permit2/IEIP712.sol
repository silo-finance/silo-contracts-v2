// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// solhint-disable

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
