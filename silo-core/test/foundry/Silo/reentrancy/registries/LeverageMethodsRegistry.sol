// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {DescriptionReentrancyTest} from "../methods/leverage/DescriptionReentrancyTest.sol";
import {SwapModuleReentrancyTest} from "../methods/leverage/SwapModuleReentrancyTest.sol";
import {RouterReentrancyTest} from "../methods/leverage/RouterReentrancyTest.sol";
import {CalculateDebtReceiveApprovalReentrancyTest} from "../methods/leverage/CalculateDebtReceiveApprovalReentrancyTest.sol";
import {OpenLeveragePositionPermitReentrancyTest} from "../methods/leverage/OpenLeveragePositionPermitReentrancyTest.sol";
import {OpenLeveragePositionReentrancyTest} from "../methods/leverage/OpenLeveragePositionReentrancyTest.sol";
import {OpenLeveragePositionDirectReentrancyTest} from "../methods/leverage/OpenLeveragePositionDirectReentrancyTest.sol";
import {OpenLeveragePositionPermitDirectReentrancyTest} from "../methods/leverage/OpenLeveragePositionPermitDirectReentrancyTest.sol";
import {CloseLeveragePositionPermitReentrancyTest} from "../methods/leverage/CloseLeveragePositionPermitReentrancyTest.sol";
import {CloseLeveragePositionReentrancyTest} from "../methods/leverage/CloseLeveragePositionReentrancyTest.sol";
import {CloseLeveragePositionDirectReentrancyTest} from "../methods/leverage/CloseLeveragePositionDirectReentrancyTest.sol";
import {CloseLeveragePositionPermitDirectReentrancyTest} from "../methods/leverage/CloseLeveragePositionPermitDirectReentrancyTest.sol";
import {OnFlashLoanReentrancyTest} from "../methods/leverage/OnFlashLoanReentrancyTest.sol";
import {NativeTokenReentrancyTest} from "../methods/leverage/NativeTokenReentrancyTest.sol";
import {FeePrecisionReentrancyTest} from "../methods/leverage/FeePrecisionReentrancyTest.sol";
import {LeverageFeeReentrancyTest} from "../methods/leverage/LeverageFeeReentrancyTest.sol";
import {RevenueReceiverReentrancyTest} from "../methods/leverage/RevenueReceiverReentrancyTest.sol";
import {RescueTokensSingleReentrancyTest} from "../methods/leverage/RescueTokensSingleReentrancyTest.sol";
import {RescueNativeTokensReentrancyTest} from "../methods/leverage/RescueNativeTokensReentrancyTest.sol";
import {CalculateLeverageFeeReentrancyTest} from "../methods/leverage/CalculateLeverageFeeReentrancyTest.sol";
import {PausedReentrancyTest} from "../methods/leverage/PausedReentrancyTest.sol";
import {MaxLeverageFeeReentrancyTest} from "../methods/leverage/MaxLeverageFeeReentrancyTest.sol";
import {DefaultAdminRoleReentrancyTest} from "../methods/leverage/DefaultAdminRoleReentrancyTest.sol";
import {GetRoleAdminReentrancyTest} from "../methods/leverage/GetRoleAdminReentrancyTest.sol";
import {GrantRoleReentrancyTest} from "../methods/leverage/GrantRoleReentrancyTest.sol";
import {HasRoleReentrancyTest} from "../methods/leverage/HasRoleReentrancyTest.sol";
import {PauserRoleReentrancyTest} from "../methods/leverage/PauserRoleReentrancyTest.sol";
import {RenounceRoleReentrancyTest} from "../methods/leverage/RenounceRoleReentrancyTest.sol";
import {RevokeRoleReentrancyTest} from "../methods/leverage/RevokeRoleReentrancyTest.sol";
import {SupportsInterfaceReentrancyTest} from "../methods/leverage/SupportsInterfaceReentrancyTest.sol";
import {PauseReentrancyTest} from "../methods/leverage/PauseReentrancyTest.sol";
import {UnpauseReentrancyTest} from "../methods/leverage/UnpauseReentrancyTest.sol";
import {SetLeverageFeeReentrancyTest} from "../methods/leverage/SetLeverageFeeReentrancyTest.sol";
import {SetRevenueReceiverReentrancyTest} from "../methods/leverage/SetRevenueReceiverReentrancyTest.sol";

contract LeverageMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new DescriptionReentrancyTest());
        _registerMethod(new SwapModuleReentrancyTest());
        _registerMethod(new RouterReentrancyTest());
        _registerMethod(new CalculateDebtReceiveApprovalReentrancyTest());
        _registerMethod(new OpenLeveragePositionPermitReentrancyTest());
        _registerMethod(new OpenLeveragePositionReentrancyTest());
        _registerMethod(new OpenLeveragePositionDirectReentrancyTest());
        _registerMethod(new OpenLeveragePositionPermitDirectReentrancyTest());
        _registerMethod(new CloseLeveragePositionPermitReentrancyTest());
        _registerMethod(new CloseLeveragePositionReentrancyTest());
        _registerMethod(new CloseLeveragePositionDirectReentrancyTest());
        _registerMethod(new CloseLeveragePositionPermitDirectReentrancyTest());
        _registerMethod(new OnFlashLoanReentrancyTest());
        _registerMethod(new NativeTokenReentrancyTest());
        _registerMethod(new FeePrecisionReentrancyTest());
        _registerMethod(new MaxLeverageFeeReentrancyTest());
        _registerMethod(new LeverageFeeReentrancyTest());
        _registerMethod(new RevenueReceiverReentrancyTest());
        _registerMethod(new RescueTokensSingleReentrancyTest());
        _registerMethod(new RescueNativeTokensReentrancyTest());
        _registerMethod(new CalculateLeverageFeeReentrancyTest());
        _registerMethod(new PausedReentrancyTest());
        _registerMethod(new DefaultAdminRoleReentrancyTest());
        _registerMethod(new GetRoleAdminReentrancyTest());
        _registerMethod(new GrantRoleReentrancyTest());
        _registerMethod(new HasRoleReentrancyTest());
        _registerMethod(new PauserRoleReentrancyTest());
        _registerMethod(new RenounceRoleReentrancyTest());
        _registerMethod(new RevokeRoleReentrancyTest());
        _registerMethod(new SupportsInterfaceReentrancyTest());
        _registerMethod(new PauseReentrancyTest());
        _registerMethod(new UnpauseReentrancyTest());
        _registerMethod(new SetLeverageFeeReentrancyTest());
        _registerMethod(new SetRevenueReceiverReentrancyTest());
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
