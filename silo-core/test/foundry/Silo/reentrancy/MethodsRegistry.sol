// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {DepositReentrancyTest} from "./silo-methods/DepositReentrancyTest.sol";
import {DepositWithTypeReentrancyTest} from "./silo-methods/DepositWithTypeReentrancyTest.sol";
import {WithdrawReentrancyTest} from "./silo-methods/WithdrawReentrancyTest.sol";
import {WithdrawWithTypeReentrancyTest} from "./silo-methods/WithdrawWithTypeReentrancyTest.sol";
import {BorrowReentrancyTest} from "./silo-methods/BorrowReentrancyTest.sol";

contract MethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new DepositReentrancyTest());
        _registerMethod(new DepositWithTypeReentrancyTest());
        _registerMethod(new WithdrawReentrancyTest());
        _registerMethod(new WithdrawWithTypeReentrancyTest());
        _registerMethod(new BorrowReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
