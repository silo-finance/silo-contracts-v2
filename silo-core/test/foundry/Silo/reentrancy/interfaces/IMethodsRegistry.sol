// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "./IMethodReentrancyTest.sol";

interface IMethodsRegistry {
    function abiFile() external pure returns (string memory);
    function methods(bytes4 _sig) external view returns (IMethodReentrancyTest);
    function supportedMethodsLength() external view returns (uint256);
    function supportedMethods(uint256 _i) external view returns (bytes4 sig);
}
