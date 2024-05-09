// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloMock is Test {
    address public immutable ADDRESS;

    constructor(address _silo) {
        ADDRESS = _silo == address(0) ? makeAddr("SiloMockAddr") : _silo;
    }

    function getCollateralAndDebtAssetsMock(uint256 _totalCollateralAssets, uint256 _totalDebtAssets) external {
        bytes memory data = abi.encodeWithSelector(ISilo.getCollateralAndDebtAssets.selector);
        vm.mockCall(ADDRESS, data, abi.encode(_totalCollateralAssets, _totalDebtAssets));
        vm.expectCall(ADDRESS, data);
    }

    // ISilo.getCollateralAssets.selector: 0xa1ff9bee
    function getCollateralAssetsMock(uint256 _totalCollateralAssets) external {
        bytes memory data = abi.encodeWithSelector(ISilo.getCollateralAssets.selector);
        vm.mockCall(ADDRESS, data, abi.encode(_totalCollateralAssets));
        vm.expectCall(ADDRESS, data);
    }

    // ISilo.getDebtAssets.selector: 0xecd658b4
    function totalMock(ISilo.AssetType _assetType, uint256 _totalDebtAssets) external {
        bytes memory data = abi.encodeWithSelector(ISilo.total.selector, _assetType);
        vm.mockCall(ADDRESS, data, abi.encode(_totalDebtAssets));
        vm.expectCall(ADDRESS, data);
    }

    function getProtectedAssetsMock(uint256 _totalProtectedAssets) external {
        bytes memory data = abi.encodeWithSelector(ISilo.total.selector, ISilo.CollateralType.Protected);
        vm.mockCall(ADDRESS, data, abi.encode(_totalProtectedAssets));
        vm.expectCall(ADDRESS, data);
    }

    // ISilo.getCollateralAndProtectedAssets.selector: 0x99d499c1
    function getCollateralAndProtectedAssetsMock(uint256 _totalCollateralAssets, uint256 _totalProtectedAssets)
        external
    {
        bytes memory data = abi.encodeWithSelector(ISilo.getCollateralAndProtectedAssets.selector);
        vm.mockCall(ADDRESS, data, abi.encode(_totalCollateralAssets, _totalProtectedAssets));
        vm.expectCall(ADDRESS, data);
    }

    function utilizationDataMock(uint256 _collateral, uint256 _debt, uint256 _timestamp)
        external
    {
        bytes memory data = abi.encodeWithSelector(ISilo.utilizationData.selector);
        vm.mockCall(ADDRESS, data, abi.encode(_collateral, _debt, _timestamp));
        vm.expectCall(ADDRESS, data);
    }

    function configMock(address _config) external {
        bytes memory data = abi.encodeWithSelector(ISilo.config.selector);
        vm.mockCall(ADDRESS, data, abi.encode(_config));
        vm.expectCall(ADDRESS, data);
    }
}
