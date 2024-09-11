// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Views} from "silo-core/contracts/lib/Views.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
forge test --ffi -vv --mc UtilizationDataTest
*/
contract UtilizationDataTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();
    }

    /*
    forge test --ffi -vv --mt test_utilizationData_zeros
    */
    function test_utilizationData_zeros() public view {
        ISilo.UtilizationData memory zeros;
        ISilo.UtilizationData memory data = silo0.utilizationData();

        assertEq(keccak256(abi.encode(zeros)), keccak256(abi.encode(data)));
    }

    /*
    forge test --ffi -vv --mt test_utilizationData_data
    */
    function test_utilizationData_data() public {
        _depositCollateral(22, address(1), SAME_ASSET);
        _borrow(3, address(1), SAME_ASSET);

        ISilo.UtilizationData memory data = silo1.utilizationData();

        assertEq(data.collateralAssets, 22);
        assertEq(data.debtAssets, 3);
        assertEq(data.interestRateTimestamp, 1);
    }
}
