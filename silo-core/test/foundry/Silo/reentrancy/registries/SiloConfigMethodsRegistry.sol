// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {
    AccrueInterestForBothSilosReentrancyTest
} from "../methods/silo-config/AccrueInterestForBothSilosReentrancyTest.sol";
import {AccrueInterestForSiloReentrancyTest} from "../methods/silo-config/AccrueInterestForSiloReentrancyTest.sol";
import {BorrowerCollateralSiloReentrancyTest} from "../methods/silo-config/BorrowerCollateralSiloReentrancyTest.sol";
import {
    GetCollateralShareTokenAndAssetReentrancyTest
} from "../methods/silo-config/GetCollateralShareTokenAndAssetReentrancyTest.sol";
import {SiloIDReentrancyTest} from "../methods/silo-config/SiloIDReentrancyTest.sol";
import {
    TurnOffReentrancyProtectionReentrancyTest
} from "../methods/silo-config/TurnOffReentrancyProtectionReentrancyTest.sol";
import {
    TurnOnReentrancyProtectionReentrancyTest
} from "../methods/silo-config/TurnOnReentrancyProtectionReentrancyTest.sol";
import {
    ReentrancyGuardEnteredReentrancyTest
} from "../methods/silo-config/ReentrancyGuardEnteredReentrancyTest.sol";
import {GetAssetForSiloReentrancyTest} from "../methods/silo-config/GetAssetForSiloReentrancyTest.sol";
import {GetConfigReentrancyTest} from "../methods/silo-config/GetConfigReentrancyTest.sol";
import {GetConfigsForBorrowReentrancyTest} from "../methods/silo-config/GetConfigsForBorrowReentrancyTest.sol";
import {GetConfigsForWithdrawReentrancyTest} from "../methods/silo-config/GetConfigsForWithdrawReentrancyTest.sol";
import {GetConfigsReentrancyTest} from "../methods/silo-config/GetConfigsReentrancyTest.sol";
import {
    GetDebtShareTokenAndAssetReentrancyTest
} from "../methods/silo-config/GetDebtShareTokenAndAssetReentrancyTest.sol";
import {GetDebtSiloReentrancyTest} from "../methods/silo-config/GetDebtSiloReentrancyTest.sol";
import {GetFeesWithAssetReentrancyTest} from "../methods/silo-config/GetFeesWithAssetReentrancyTest.sol";
import {GetShareTokensReentrancyTest} from "../methods/silo-config/GetShareTokensReentrancyTest.sol";
import {GetSilosReentrancyTest} from "../methods/silo-config/GetSilosReentrancyTest.sol";
import {HasDebtInOtherSiloReentrancyTest} from "../methods/silo-config/HasDebtInOtherSiloReentrancyTest.sol";
import {OnDebtTransferReentrancyTest} from "../methods/silo-config/OnDebtTransferReentrancyTest.sol";
import {
    SetOtherSiloAsCollateralSiloReentrancyTest
} from "../methods/silo-config/SetOtherSiloAsCollateralSiloReentrancyTest.sol";
import{
    SetThisSiloAsCollateralSiloReentrancyTest
} from "../methods/silo-config/SetThisSiloAsCollateralSiloReentrancyTest.sol";

contract SiloConfigMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new AccrueInterestForBothSilosReentrancyTest());
        _registerMethod(new AccrueInterestForSiloReentrancyTest());
        _registerMethod(new BorrowerCollateralSiloReentrancyTest());
        _registerMethod(new SiloIDReentrancyTest());
        _registerMethod(new ReentrancyGuardEnteredReentrancyTest());
        _registerMethod(new GetAssetForSiloReentrancyTest());
        _registerMethod(new GetCollateralShareTokenAndAssetReentrancyTest());
        _registerMethod(new GetConfigReentrancyTest());
        _registerMethod(new GetConfigsForBorrowReentrancyTest());
        _registerMethod(new GetConfigsForWithdrawReentrancyTest());
        _registerMethod(new GetConfigsReentrancyTest());
        _registerMethod(new GetDebtShareTokenAndAssetReentrancyTest());
        _registerMethod(new GetDebtSiloReentrancyTest());
        _registerMethod(new GetFeesWithAssetReentrancyTest());
        _registerMethod(new GetShareTokensReentrancyTest());
        _registerMethod(new GetSilosReentrancyTest());
        _registerMethod(new HasDebtInOtherSiloReentrancyTest());
        _registerMethod(new OnDebtTransferReentrancyTest());
        _registerMethod(new SetOtherSiloAsCollateralSiloReentrancyTest());
        _registerMethod(new SetThisSiloAsCollateralSiloReentrancyTest());
        _registerMethod(new TurnOffReentrancyProtectionReentrancyTest());
        _registerMethod(new TurnOnReentrancyProtectionReentrancyTest());
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
