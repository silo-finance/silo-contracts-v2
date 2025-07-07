// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {DescriptionReentrancyTest} from "../methods/leverage/DescriptionReentrancyTest.sol";
import {SwapModuleReentrancyTest} from "../methods/leverage/SwapModuleReentrancyTest.sol";
import {CalculateDebtReceiveApprovalReentrancyTest} from "../methods/leverage/CalculateDebtReceiveApprovalReentrancyTest.sol";
import {OpenLeveragePositionPermitReentrancyTest} from "../methods/leverage/OpenLeveragePositionPermitReentrancyTest.sol";
import {OpenLeveragePositionReentrancyTest} from "../methods/leverage/OpenLeveragePositionReentrancyTest.sol";
import {CloseLeveragePositionPermitReentrancyTest} from "../methods/leverage/CloseLeveragePositionPermitReentrancyTest.sol";
import {CloseLeveragePositionReentrancyTest} from "../methods/leverage/CloseLeveragePositionReentrancyTest.sol";
import {OnFlashLoanReentrancyTest} from "../methods/leverage/OnFlashLoanReentrancyTest.sol";
import {NativeTokenReentrancyTest} from "../methods/leverage/NativeTokenReentrancyTest.sol";
import {FeePrecisionReentrancyTest} from "../methods/leverage/FeePrecisionReentrancyTest.sol";
import {LeverageFeeReentrancyTest} from "../methods/leverage/LeverageFeeReentrancyTest.sol";
import {RevenueReceiverReentrancyTest} from "../methods/leverage/RevenueReceiverReentrancyTest.sol";
import {PauseReentrancyTest} from "../methods/leverage/PauseReentrancyTest.sol";
import {UnpauseReentrancyTest} from "../methods/leverage/UnpauseReentrancyTest.sol";
import {SetLeverageFeeReentrancyTest} from "../methods/leverage/SetLeverageFeeReentrancyTest.sol";
import {SetRevenueReceiverReentrancyTest} from "../methods/leverage/SetRevenueReceiverReentrancyTest.sol";
import {RescueTokensArrayReentrancyTest} from "../methods/leverage/RescueTokensArrayReentrancyTest.sol";
import {RescueTokensSingleReentrancyTest} from "../methods/leverage/RescueTokensSingleReentrancyTest.sol";
import {CalculateLeverageFeeReentrancyTest} from "../methods/leverage/CalculateLeverageFeeReentrancyTest.sol";
import {OwnerReentrancyTest} from "../methods/leverage/OwnerReentrancyTest.sol";
import {PendingOwnerReentrancyTest} from "../methods/leverage/PendingOwnerReentrancyTest.sol";
import {TransferOwnershipReentrancyTest} from "../methods/leverage/TransferOwnershipReentrancyTest.sol";
import {AcceptOwnershipReentrancyTest} from "../methods/leverage/AcceptOwnershipReentrancyTest.sol";
import {RenounceOwnershipReentrancyTest} from "../methods/leverage/RenounceOwnershipReentrancyTest.sol";
import {PausedReentrancyTest} from "../methods/leverage/PausedReentrancyTest.sol";

contract LeverageMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new DescriptionReentrancyTest());
        _registerMethod(new SwapModuleReentrancyTest());
        _registerMethod(new CalculateDebtReceiveApprovalReentrancyTest());
        _registerMethod(new OpenLeveragePositionPermitReentrancyTest()); // TODO
        _registerMethod(new OpenLeveragePositionReentrancyTest());
        _registerMethod(new CloseLeveragePositionPermitReentrancyTest()); // TODO
        _registerMethod(new CloseLeveragePositionReentrancyTest());
        _registerMethod(new OnFlashLoanReentrancyTest());
        _registerMethod(new NativeTokenReentrancyTest());
        _registerMethod(new FeePrecisionReentrancyTest());
        _registerMethod(new LeverageFeeReentrancyTest());
        _registerMethod(new RevenueReceiverReentrancyTest());
        _registerMethod(new PauseReentrancyTest());
        _registerMethod(new UnpauseReentrancyTest());
        _registerMethod(new SetLeverageFeeReentrancyTest());
        _registerMethod(new SetRevenueReceiverReentrancyTest());
        _registerMethod(new RescueTokensArrayReentrancyTest());
        _registerMethod(new RescueTokensSingleReentrancyTest());
        _registerMethod(new CalculateLeverageFeeReentrancyTest());
        _registerMethod(new OwnerReentrancyTest());
        _registerMethod(new PendingOwnerReentrancyTest());
        _registerMethod(new TransferOwnershipReentrancyTest());
        _registerMethod(new AcceptOwnershipReentrancyTest());
        _registerMethod(new RenounceOwnershipReentrancyTest());
        _registerMethod(new PausedReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure returns (string memory) {
        // solhint-disable-next-line max-line-length
        return "/cache/foundry/out/silo-core/LeverageUsingSiloFlashloanWithGeneralSwap.sol/LeverageUsingSiloFlashloanWithGeneralSwap.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
