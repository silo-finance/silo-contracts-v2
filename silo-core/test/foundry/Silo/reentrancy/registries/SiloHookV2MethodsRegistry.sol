// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";

import {LiquidationCallByDefaultingReentrancyTest} from "../methods/silo-hook-v2/LiquidationCallByDefaultingReentrancyTest.sol";
import {SiloHookV1MethodsRegistry} from "./SiloHookV1MethodsRegistry.sol";


contract SiloHookV2MethodsRegistry is SiloHookV1MethodsRegistry {
    constructor() {
        _registerMethod(new LiquidationCallByDefaultingReentrancyTest());
    }

    function abiFile() external pure override returns (string memory) {
        return "/cache/foundry/out/silo-core/SiloHookV2.sol/SiloHookV2.json";
    }
}
