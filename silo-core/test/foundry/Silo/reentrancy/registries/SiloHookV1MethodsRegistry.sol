// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {AcceptOwnershipReentrancyTest} from "../methods/silo-hook-v1/AcceptOwnershipReentrancyTest.sol";
import {AfterActionReentrancyTest} from "../methods/silo-hook-v1/AfterActionReentrancyTest.sol";
import {AddNotificationReceiverReentrancyTest} from "../methods/silo-hook-v1/AddNotificationReceiverReentrancyTest.sol";
import {AddIncentivesClaimingLogicReentrancyTest} from "../methods/silo-hook-v1/AddIncentivesClaimingLogicReentrancyTest.sol";
import {BeforeActionReentrancyTest} from "../methods/silo-hook-v1/BeforeActionReentrancyTest.sol";
import {GetIncentivesClaimingLogicsReentrancyTest} from "../methods/silo-hook-v1/GetIncentivesClaimingLogicsReentrancyTest.sol";
import {GetNotificationReceiversReentrancyTest} from "../methods/silo-hook-v1/GetNotificationReceiversReentrancyTest.sol";
import {HookReceiverConfigReentrancyTest} from "../methods/silo-hook-v1/HookReceiverConfigReentrancyTest.sol";
import {InitializeReentrancyTest} from "../methods/silo-hook-v1/InitializeReentrancyTest.sol";
import {MaxLiquidationReentrancyTest} from "../methods/silo-hook-v1/MaxLiquidationReentrancyTest.sol";
import {OwnerReentrancyTest} from "../methods/silo-hook-v1/OwnerReentrancyTest.sol";
import {PendingOwnerReentrancyTest} from "../methods/silo-hook-v1/PendingOwnerReentrancyTest.sol";
import {LiquidationCallReentrancyTest} from "../methods/silo-hook-v1/LiquidationCallReentrancyTest.sol";
import {RenounceOwnershipReentrancyTest} from "../methods/silo-hook-v1/RenounceOwnershipReentrancyTest.sol";
import {RemoveNotificationReceiverReentrancyTest} from "../methods/silo-hook-v1/RemoveNotificationReceiverReentrancyTest.sol";
import {RemoveIncentivesClaimingLogicReentrancyTest} from "../methods/silo-hook-v1/RemoveIncentivesClaimingLogicReentrancyTest.sol";
import {SiloConfigReentrancyTest} from "../methods/silo-hook-v1/SiloConfigReentrancyTest.sol";
import {TransferOwnershipReentrancyTest} from "../methods/silo-hook-v1/TransferOwnershipReentrancyTest.sol";

contract SiloHookV1MethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new AcceptOwnershipReentrancyTest());
        _registerMethod(new AfterActionReentrancyTest());
        _registerMethod(new AddNotificationReceiverReentrancyTest());
        _registerMethod(new AddIncentivesClaimingLogicReentrancyTest());
        _registerMethod(new BeforeActionReentrancyTest());
        _registerMethod(new HookReceiverConfigReentrancyTest());
        _registerMethod(new InitializeReentrancyTest());
        _registerMethod(new MaxLiquidationReentrancyTest());
        _registerMethod(new OwnerReentrancyTest());
        _registerMethod(new PendingOwnerReentrancyTest());
        _registerMethod(new LiquidationCallReentrancyTest());
        _registerMethod(new RemoveNotificationReceiverReentrancyTest());
        _registerMethod(new RemoveIncentivesClaimingLogicReentrancyTest());
        _registerMethod(new RenounceOwnershipReentrancyTest());
        _registerMethod(new SiloConfigReentrancyTest());
        _registerMethod(new TransferOwnershipReentrancyTest());
        _registerMethod(new GetIncentivesClaimingLogicsReentrancyTest());
        _registerMethod(new GetNotificationReceiversReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure returns (string memory) {
        return "/cache/foundry/out/silo-core/SiloHookV1.sol/SiloHookV1.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}