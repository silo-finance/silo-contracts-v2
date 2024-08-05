// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {AcceptOwnersipReentrancyTest} from "../methods/gauge-hook-receiver/AcceptOwnersipReentrancyTest.sol";
import {AfterActionReentrancyTest} from "../methods/gauge-hook-receiver/AfterActionReentrancyTest.sol";
import {BeforeActionReentrancyTest} from "../methods/gauge-hook-receiver/BeforeActionReentrancyTest.sol";
import {ConfiguredGaugesReentrancyTest} from "../methods/gauge-hook-receiver/ConfiguredGaugesReentrancyTest.sol";
import {GaugeReentrancyTest} from "../methods/gauge-hook-receiver/GaugeReentrancyTest.sol";
import {HookReceiverConfigReentrancyTest} from "../methods/gauge-hook-receiver/HookReceiverConfigReentrancyTest.sol";
import {InitializeReentrancyTest} from "../methods/gauge-hook-receiver/InitializeReentrancyTest.sol";
import {MaxLiquidationReentrancyTest} from "../methods/gauge-hook-receiver/MaxLiquidationReentrancyTest.sol";
import {OwnerReentrancyTest} from "../methods/gauge-hook-receiver/OwnerReentrancyTest.sol";
import {PendingOwnerReentrancyTest} from "../methods/gauge-hook-receiver/PendingOwnerReentrancyTest.sol";
import {LiquidationCallReentrancyTest} from "../methods/gauge-hook-receiver/LiquidationCallReentrancyTest.sol";
import {RemoveGaugeReentrancyTest} from "../methods/gauge-hook-receiver/RemoveGaugeReentrancyTest.sol";
import {RenounceOwnersipReentrancyTest} from "../methods/gauge-hook-receiver/RenounceOwnersipReentrancyTest.sol";
import {SetGaugeReentrancyTest} from "../methods/gauge-hook-receiver/SetGaugeReentrancyTest.sol";
import {ShareTokenReentrancyTest} from "../methods/gauge-hook-receiver/ShareTokenReentrancyTest.sol";
import {SiloConfigReentrancyTest} from "../methods/gauge-hook-receiver/SiloConfigReentrancyTest.sol";
import {TransferOwnersipReentrancyTest} from "../methods/gauge-hook-receiver/TransferOwnersipReentrancyTest.sol";

contract GaugeHookReceiverMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new AcceptOwnersipReentrancyTest());
        _registerMethod(new AfterActionReentrancyTest());
        _registerMethod(new BeforeActionReentrancyTest());
        _registerMethod(new ConfiguredGaugesReentrancyTest());
        _registerMethod(new GaugeReentrancyTest());
        _registerMethod(new HookReceiverConfigReentrancyTest());
        _registerMethod(new InitializeReentrancyTest());
        _registerMethod(new MaxLiquidationReentrancyTest());
        _registerMethod(new OwnerReentrancyTest());
        _registerMethod(new PendingOwnerReentrancyTest());
        // _registerMethod(new LiquidationCallReentrancyTest()); TODO: add reentrancy protection
        _registerMethod(new RemoveGaugeReentrancyTest());
        _registerMethod(new RenounceOwnersipReentrancyTest());
        _registerMethod(new SetGaugeReentrancyTest());
        _registerMethod(new ShareTokenReentrancyTest());
        _registerMethod(new SiloConfigReentrancyTest());
        _registerMethod(new TransferOwnersipReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure returns (string memory) {
        return "/cache/foundry/out/silo-core/GaugeHookReceiver.sol/GaugeHookReceiver.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}