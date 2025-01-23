// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "silo-core/test/foundry/Silo/reentrancy/interfaces/IMethodsRegistry.sol";

import {SetCuratorReentrancyTest} from "../methods/SetCuratorReentrancyTest.sol";
import {DecimalsReentrancyTest} from "../methods/DecimalsReentrancyTest.sol";
import {DepositReentrancyTest} from "../methods/DepositReentrancyTest.sol";

contract SiloVaultMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new SetCuratorReentrancyTest());
        _registerMethod(new DecimalsReentrancyTest());
        _registerMethod(new DepositReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure virtual returns (string memory) {
        return "/cache/foundry/out/silo-vaults/SiloVault.sol/SiloVault.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}