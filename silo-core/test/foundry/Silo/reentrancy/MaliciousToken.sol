// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";
import {Registries} from "./registries/Registries.sol";
import {LeverageMethodsRegistry} from "./registries/LeverageMethodsRegistry.sol";
import {IMethodsRegistry} from "./interfaces/IMethodsRegistry.sol";
import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "./TestState.sol";
import {MintableToken} from "../../_common/MintableToken.sol";

contract MaliciousToken is MintableToken, Test {
    IMethodsRegistry[] internal _methodRegistries;
    LeverageMethodsRegistry internal _leverageMethodsRegistry;

    constructor() MintableToken(18) {
        Registries registries = new Registries();
        _methodRegistries = registries.list();
        _leverageMethodsRegistry = new LeverageMethodsRegistry();
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _tryToReenter();

        super.transfer(recipient, amount);

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _tryToReenter();

        super.transferFrom(sender, recipient, amount);

        return true;
    }

    function _tryToReenter() internal {
        if (!TestStateLib.reenter() && !TestStateLib.leverageReenter()) return;

        // reenter before transfer
        emit log_string("\tTrying to reenter:");

        ISiloConfig config = TestStateLib.siloConfig();

        if (TestStateLib.reenter()) {
            bool entered = config.reentrancyGuardEntered();
            assertTrue(entered, "Reentrancy is not enabled on a token transfer");

            TestStateLib.disableReentrancy();
            _callAllMethods();
            TestStateLib.enableReentrancy();
        }

        if (TestStateLib.leverageReenter()) {
            address leverage = TestStateLib.leverage();

            // bool entered = TransientReentrancy(leverage).reentrancyGuardEntered();
            // assertTrue(entered, "Reentrancy is not enabled on a token transfer when leverage");

            TestStateLib.disableLeverageReentrancy();
            _callOnlyLeverageMethods();
            TestStateLib.enableLeverageReentrancy();
        }
    }

    function _callAllMethods() internal {
        emit log_string("[MaliciousToken] calling all methods");

        uint256 stateBeforeReentrancyTest = vm.snapshotState();

        for (uint j = 0; j < _methodRegistries.length; j++) {
            if (Strings.equal(_methodRegistries[j].abiFile(), _leverageMethodsRegistry.abiFile())) continue;

            uint256 totalMethods = _methodRegistries[j].supportedMethodsLength();

            for (uint256 i = 0; i < totalMethods; i++) {
                bytes4 methodSig = _methodRegistries[j].supportedMethods(i);
                IMethodReentrancyTest method = _methodRegistries[j].methods(methodSig);

                emit log_string(string.concat("\t  ", method.methodDescription()));

                method.verifyReentrancy();

                vm.revertToState(stateBeforeReentrancyTest);
            }
        }
    }

    function _callOnlyLeverageMethods() internal {
        emit log_string("[MaliciousToken] calling only leverage methods");

        uint256 stateBeforeReentrancyTest = vm.snapshotState();

        uint256 totalMethods = _leverageMethodsRegistry.supportedMethodsLength();

        for (uint256 i = 0; i < totalMethods; i++) {
            bytes4 methodSig = _leverageMethodsRegistry.supportedMethods(i);
            IMethodReentrancyTest method = _leverageMethodsRegistry.methods(methodSig);

            emit log_string(string.concat("\t  ", method.methodDescription()));

            method.verifyReentrancy();

            vm.revertToState(stateBeforeReentrancyTest);
        }
    }
}
