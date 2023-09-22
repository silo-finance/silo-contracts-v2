// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

contract TokenMock {
    address public immutable ADDRESS;

    Vm private immutable vm;

    constructor (Vm _vm, address _address) {
        vm = _vm;
        ADDRESS = _address == address(0) ? address(0x97263586483648732222222222222) : _address;
    }

    function balanceOfMock(address _owner, uint256 _shares) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, _owner),
            abi.encode(_shares)
        );
    }

    function totalSupplyMock(uint256 _totalSupply) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.totalSupply.selector),
            abi.encode(_totalSupply)
        );
    }
}
