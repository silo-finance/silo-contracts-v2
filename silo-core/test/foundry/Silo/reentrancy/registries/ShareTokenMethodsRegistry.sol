// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {DomainSeparatorReentrancyTest} from "../methods/share-token/DomainSeparatorReentrancyTest.sol";
import {AllowanceSeparatorReentrancyTest} from "../methods/share-token/AllowanceSeparatorReentrancyTest.sol";
import {ApproveReentrancyTest} from "../methods/share-token/ApproveReentrancyTest.sol";
import {BalanceOfReentrancyTest} from "../methods/share-token/BalanceOfReentrancyTest.sol";
import {BalanceOfAndTotalSupplyReentrancyTest} from "../methods/share-token/BalanceOfAndTotalSupplyReentrancyTest.sol";
import {BurnReentrancyTest} from "../methods/share-token/BurnReentrancyTest.sol";
import {DecimalsReentrancyTest} from "../methods/share-token/DecimalsReentrancyTest.sol";
import {Eip712DomainReentrancyTest} from "../methods/share-token/Eip712DomainReentrancyTest.sol";
import {ForwardApproveReentrancyTest} from "../methods/share-token/ForwardApproveReentrancyTest.sol";
import {ForwardTransferReentrancyTest} from "../methods/share-token/ForwardTransferReentrancyTest.sol";
import {ForwardTransferFromReentrancyTest} from "../methods/share-token/ForwardTransferFromReentrancyTest.sol";
import {HookReceiverReentrancyTest} from "../methods/share-token/HookReceiverReentrancyTest.sol";
import {HookSetupReentrancyTest} from "../methods/share-token/HookSetupReentrancyTest.sol";
import {InitializeReentrancyTest} from "../methods/share-token/InitializeReentrancyTest.sol";
import {MintReentrancyTest} from "../methods/share-token/MintReentrancyTest.sol";
import {NameReentrancyTest} from "../methods/share-token/NameReentrancyTest.sol";
import {NoncesReentrancyTest} from "../methods/share-token/NoncesReentrancyTest.sol";

abstract contract ShareTokenMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new DomainSeparatorReentrancyTest());
        _registerMethod(new AllowanceSeparatorReentrancyTest());
        _registerMethod(new ApproveReentrancyTest());
        _registerMethod(new BalanceOfReentrancyTest());
        _registerMethod(new BalanceOfAndTotalSupplyReentrancyTest());
        _registerMethod(new BurnReentrancyTest());
        _registerMethod(new DecimalsReentrancyTest());
        _registerMethod(new Eip712DomainReentrancyTest());
        _registerMethod(new ForwardApproveReentrancyTest());
        _registerMethod(new ForwardTransferReentrancyTest());
        _registerMethod(new ForwardTransferFromReentrancyTest());
        _registerMethod(new HookReceiverReentrancyTest());
        _registerMethod(new HookSetupReentrancyTest());
        _registerMethod(new InitializeReentrancyTest());
        _registerMethod(new MintReentrancyTest());
        _registerMethod(new NameReentrancyTest());
        _registerMethod(new NoncesReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure virtual returns (string memory) {}

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
