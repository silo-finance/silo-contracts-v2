// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {MethodsRegistry} from "./MethodsRegistry.sol";
import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "./TestState.sol";

contract MaliciousToken is ERC20, Test {
    MethodsRegistry internal _registry;

    string internal _prefix = "\t";

    constructor() ERC20("MaliciousToken", "MLST") {
        _registry = new MethodsRegistry();
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

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function _tryToReenter() internal {
        if (!TestStateLib.reenter()) return;

        // reenter before transfer
        emit log_string("\tTrying to reenter:");

        uint256 totalMethods = _registry.supportedMethodsLength();

        for (uint256 i = 0; i < totalMethods; i++) {
            bytes4 methodSig = _registry.supportedMethods(i);
            IMethodReentrancyTest method = _registry.methods(methodSig);

            emit log_string(string.concat("\t  ", method.methodDescription()));

            method.verifyReentrancy();
        }
    }
}
