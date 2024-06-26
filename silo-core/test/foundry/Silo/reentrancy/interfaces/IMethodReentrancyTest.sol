// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface IMethodReentrancyTest {
    function callMethod() external;
    function verifyReentrancy() external;
    
    // For these details, see cache/foundry/out/silo-core/<abi_file>.json 
    // abi.methodIdentifiers
    function methodSignature() external view returns (bytes4 sig);
    function methodDescription() external pure returns (string memory description);
}
