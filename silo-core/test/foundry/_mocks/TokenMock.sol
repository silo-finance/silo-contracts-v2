// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract TokenMock {
    address public immutable ADDRESS;

    Vm private immutable vm;

    constructor(Vm _vm, address _token) {
        vm = _vm;
        ADDRESS = _token == address(0) ? address(0x5224928173683243804202752353186) : _token;
    }

    function balanceOfMock(address _owner, uint256 _balance) public {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, _owner),
            abi.encode(_balance)
        );
    }

    function transferFromMock(address _from, address _to, uint256 _amount) public {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.transferFrom.selector, _from, _to, _amount),
            abi.encode(true)
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
