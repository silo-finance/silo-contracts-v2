// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract Gas is SiloLittleHelper {
    uint256 constant ASSETS = 1e18;
    address constant BORROWER = address(0x1122);
    address constant DEPOSITOR = address(0x9988);

    Vm private immutable _vm;

    constructor(Vm __vm) {
        _vm = __vm;
    }

    function _gasTestsInit() internal {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        __init(_vm, token0, token1, silo0, silo1);

        uint256 max = 2 ** 128 - 1;

        _mintTokens(token0, max, BORROWER);
        _mintTokens(token1, max, DEPOSITOR);

        _vm.prank(BORROWER);
        token0.approve(address(silo0), max);
        _vm.prank(BORROWER);
        token1.approve(address(silo1), max);

        _vm.prank(DEPOSITOR);
        token0.approve(address(silo0), max);
        _vm.prank(DEPOSITOR);
        token1.approve(address(silo1), max);
    }

    function _action(
        address _sender,
        ISilo _target,
        bytes memory _data,
        string memory _msg,
        uint256 _expectedGas
    ) internal returns (uint256 gas) {
        _vm.startPrank(_sender, _sender);

        uint256 gasStart = gasleft();
        (bool success,) = address(_target).call(_data);
        uint256 gasEnd = gasleft();
        gas = gasStart - gasEnd;

        _vm.stopPrank();

        if (!success) {
            revert(string(abi.encodePacked("[GAS] ERROR: revert for ", _msg)));
        }

        if (gas != _expectedGas) {
            uint256 diff = _expectedGas > gas ? _expectedGas - gas : gas - _expectedGas;
            string memory diffSign = _expectedGas > gas ? "-" : "+";
            if (diff < 100) {
                console2.log(string(abi.encodePacked("[GAS] ", _msg, ": %s (expected ", diffSign, "%s)")), gas, diff);
            } else {
                revert(string(abi.encodePacked(
                    "[GAS] invalid gas for ",
                    _msg,
                    ": expected ",
                    Strings.toString(_expectedGas),
                    " got ",
                    Strings.toString(gas)
                )));
            }
        } else {
            console2.log("[GAS] %s: %s", _msg, gas);
        }
    }
}
