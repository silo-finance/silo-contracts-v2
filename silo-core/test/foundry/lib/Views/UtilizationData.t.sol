// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Views} from "silo-core/contracts/lib/Views.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

/*
forge test --ffi -vv --mc UtilizationDataTest
*/
contract UtilizationDataTest is Test {
    /*
    forge test --ffi -vv --mt test_utilizationData_zeros
    */
    function test_utilizationData_zeros() public view {
        ISilo.UtilizationData memory zeros;
        ISilo.UtilizationData memory data = Views.utilizationData();

        assertEq(keccak256(abi.encode(zeros)), keccak256(abi.encode(data)));
    }

    /*
    forge test --ffi -vv --mt test_utilizationData_data
    */
    function test_utilizationData_data() public {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[AssetTypes.COLLATERAL] = 1;
        $.totalAssets[AssetTypes.DEBT] = 2;
        $.interestRateTimestamp = 3;

        ISilo.UtilizationData memory data = Views.utilizationData();

        assertEq(data.collateralAssets, 1);
        assertEq(data.debtAssets, 2);
        assertEq(data.interestRateTimestamp, 3);
    }
}
