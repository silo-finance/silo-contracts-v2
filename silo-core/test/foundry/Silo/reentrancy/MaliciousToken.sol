// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Registries} from "./registries/Registries.sol";
import {IMethodsRegistry} from "./interfaces/IMethodsRegistry.sol";
import {SiloMethodsRegistry} from "./registries/SiloMethodsRegistry.sol";
import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "./TestState.sol";

contract MaliciousToken is ERC20, Test {
    IMethodsRegistry[] internal _methodRegistries;

    constructor() ERC20("MaliciousToken", "MLST") {
        Registries registries = new Registries();
        _methodRegistries = registries.list();
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
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
        if (!TestStateLib.reenter()) return;

        // reenter before transfer
        emit log_string("\tTrying to reenter:");

        ISiloConfig config = TestStateLib.siloConfig();

        bool entered = config.reentrancyGuardEntered();
        assertTrue(entered, "Reentrancy is not enabled on a token transfer");

        uint256 stateBeforeReentrancyTest = vm.snapshot();

        for (uint j = 0; j < _methodRegistries.length; j++) {
            uint256 totalMethods = _methodRegistries[j].supportedMethodsLength();

            for (uint256 i = 0; i < totalMethods; i++) {
                bytes4 methodSig = _methodRegistries[j].supportedMethods(i);
                IMethodReentrancyTest method = _methodRegistries[j].methods(methodSig);

                emit log_string(string.concat("\t  ", method.methodDescription()));

                method.verifyReentrancy();

                vm.revertTo(stateBeforeReentrancyTest);
            }
        }
    }
}
