// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {SiloIDReentrancyTest} from "../methods/silo-config/SiloIDReentrancyTest.sol";
import {AccrueInterestAndGetConfigReentrancyTest}
    from "../methods/silo-config/AccrueInterestAndGetConfigReentrancyTest.sol";
import {AccrueInterestAndGetConfigOptimisedReentrancyTest}
    from "../methods/silo-config/AccrueInterestAndGetConfigOptimisedReentrancyTest.sol";
import {AccrueInterestAndGetConfigsReentrancyTest}
    from "../methods/silo-config/AccrueInterestAndGetConfigsReentrancyTest.sol";
import {CloseDebtReentrancyTest} from "../methods/silo-config/CloseDebtReentrancyTest.sol";
import {CrossNonReentrantAfterReentrancyTest} from "../methods/silo-config/CrossNonReentrantAfterReentrancyTest.sol";
import {CrossNonReentrantBeforeReentrancyTest} from "../methods/silo-config/CrossNonReentrantBeforeReentrancyTest.sol";
import {CrossReentrantStatusReentrancyTest} from "../methods/silo-config/CrossReentrantStatusReentrancyTest.sol";
import {GetAssetForSiloReentrancyTest} from "../methods/silo-config/GetAssetForSiloReentrancyTest.sol";
import {GetConfigReentrancyTest} from "../methods/silo-config/GetConfigReentrancyTest.sol";
import {GetConfigsReentrancyTest} from "../methods/silo-config/GetConfigsReentrancyTest.sol";
import {GetFeesWithAssetReentrancyTest} from "../methods/silo-config/GetFeesWithAssetReentrancyTest.sol";
import {GetShareTokensReentrancyTest} from "../methods/silo-config/GetShareTokensReentrancyTest.sol";
import {GetSilosReentrancyTest} from "../methods/silo-config/GetSilosReentrancyTest.sol";
import {OnDebtTransferReentrancyTest} from "../methods/silo-config/OnDebtTransferReentrancyTest.sol";

contract SiloConfigMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new SiloIDReentrancyTest());
        _registerMethod(new AccrueInterestAndGetConfigReentrancyTest());
        _registerMethod(new AccrueInterestAndGetConfigOptimisedReentrancyTest());
        // _registerMethod(new AccrueInterestAndGetConfigsReentrancyTest()); // TODO: bug with permissions
        _registerMethod(new CloseDebtReentrancyTest());
        _registerMethod(new CrossNonReentrantAfterReentrancyTest());
        _registerMethod(new CrossNonReentrantBeforeReentrancyTest());
        _registerMethod(new CrossReentrantStatusReentrancyTest());
        _registerMethod(new GetAssetForSiloReentrancyTest());
        _registerMethod(new GetConfigReentrancyTest());
        _registerMethod(new GetConfigsReentrancyTest());
        _registerMethod(new GetFeesWithAssetReentrancyTest());
        _registerMethod(new GetShareTokensReentrancyTest());
        _registerMethod(new GetSilosReentrancyTest());
        _registerMethod(new OnDebtTransferReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure returns (string memory) {
        return "/cache/foundry/out/silo-core/SiloConfig.sol/SiloConfig.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
