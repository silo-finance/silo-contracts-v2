// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {DepositReentrancyTest} from "./silo-methods/DepositReentrancy.t.sol";
import {DepositWithTypeReentrancyTest} from "./silo-methods/DepositWithTypeReentrancy.t.sol";
import {WithdrawReentrancyTest} from "./silo-methods/WithdrawReentrancy.t.sol";

contract MethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new DepositReentrancyTest());
        _registerMethod(new DepositWithTypeReentrancyTest());
        _registerMethod(new WithdrawReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
