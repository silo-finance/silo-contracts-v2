// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

abstract contract LocalVm {
    address constant private VM_ADDRESS = address(bytes20(uint160(uint256(keccak256('hevm cheat code')))));

    Vm internal constant _vm = Vm(VM_ADDRESS);
}
