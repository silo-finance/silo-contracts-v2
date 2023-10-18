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

    function getProtectedAssetsMock(uint256 _totalProtectedAssets) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISilo.getProtectedAssets.selector),
            abi.encode(_totalProtectedAssets)
        );
    }

    function getCollateralAndProtectedAssetsMock(uint256 _totalCollateralAssets, uint256 _totalProtectedAssets)
        external
    {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISilo.getCollateralAndProtectedAssets.selector),
            abi.encode(_totalCollateralAssets, _totalProtectedAssets)
        );
    }

    function utilizationDataMock(uint256 _collateral, uint256 _debt, uint256 _timestamp)
        external
    {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISilo.utilizationData.selector),
            abi.encode(_collateral, _debt, _timestamp)
        );
    }
}
