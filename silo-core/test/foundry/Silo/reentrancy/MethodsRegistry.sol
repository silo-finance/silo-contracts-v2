// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {AccrueInterestReentrancyTest} from "./silo-methods/AccrueInterestReentrancyTest.sol";
import {AccrueInterestForConfigReentrancyTest} from "./silo-methods/AccrueInterestForConfigReentrancyTest.sol";
import {AllowanceReentrancyTest} from "./silo-methods/AllowanceReentrancyTest.sol";
import {ApproveReentrancyTest} from "./silo-methods/ApproveReentrancyTest.sol";
import {AssetReentrancyTest} from "./silo-methods/AssetReentrancyTest.sol";
import {BalanceOfReentrancyTest} from "./silo-methods/BalanceOfReentrancyTest.sol";
import {BorrowReentrancyTest} from "./silo-methods/BorrowReentrancyTest.sol";
import {BorrowSharesReentrancyTest} from "./silo-methods/BorrowSharesReentrancyTest.sol";
import {CallOnBehalfOfSiloReentrancyTest} from "./silo-methods/CallOnBehalfOfSiloReentrancyTest.sol";
import {DepositReentrancyTest} from "./silo-methods/DepositReentrancyTest.sol";
import {DepositWithTypeReentrancyTest} from "./silo-methods/DepositWithTypeReentrancyTest.sol";
import {WithdrawReentrancyTest} from "./silo-methods/WithdrawReentrancyTest.sol";
import {WithdrawWithTypeReentrancyTest} from "./silo-methods/WithdrawWithTypeReentrancyTest.sol";

contract MethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new AccrueInterestReentrancyTest());
        _registerMethod(new AccrueInterestForConfigReentrancyTest());
        _registerMethod(new AllowanceReentrancyTest());
        _registerMethod(new ApproveReentrancyTest());
        _registerMethod(new AssetReentrancyTest());
        _registerMethod(new BalanceOfReentrancyTest());
        _registerMethod(new BorrowReentrancyTest());
        _registerMethod(new BorrowSharesReentrancyTest());
        _registerMethod(new CallOnBehalfOfSiloReentrancyTest());
        _registerMethod(new DepositReentrancyTest());
        _registerMethod(new DepositWithTypeReentrancyTest());
        _registerMethod(new WithdrawReentrancyTest());
        _registerMethod(new WithdrawWithTypeReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
