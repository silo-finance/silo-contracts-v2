// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloMock {
    address public immutable ADDRESS;

    Vm private immutable vm;

    constructor(Vm _vm, address _silo) {
        vm = _vm;
        ADDRESS = _silo == address(0) ? address(0x51101111111111111111) : _silo;
    }

    function totalMock(ISilo.AssetType _type, uint256 _totalAssets) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISilo.total.selector, _type),
            abi.encode(_totalAssets)
        );
    }
}
