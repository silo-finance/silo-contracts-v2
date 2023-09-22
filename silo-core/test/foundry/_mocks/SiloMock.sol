// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloMock {
    address public constant ADDRESS = address(0x83652230941111111111111111);

    Vm private immutable vm;

    constructor (Vm _vm) {
        vm = _vm;
    }

    function getCollateralAssetsMock(uint256 _totalCollateralAssets) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISilo.getCollateralAssets.selector),
            abi.encode(_totalCollateralAssets)
        );
    }

    function getDebtAssetsMock(uint256 _totalDebtAssets) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISilo.getDebtAssets.selector),
            abi.encode(_totalDebtAssets)
        );
    }
}
