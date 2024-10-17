// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract LeverageSameAsset1stGasTest is Gas, Test {
    function setUp() public {
        _gasTestsInit();
    }

    /*
    forge test -vv --ffi --mt test_gas_leverageSameAsset
    */
    function test_gas_leverageSameAsset1st() public {
        token1.mint(BORROWER, ASSETS);

        vm.prank(BORROWER);
        token1.approve(address(silo1), ASSETS);

        uint256 depositAssets = ASSETS * 2;

        _action(
            BORROWER,
            address(silo1),
            abi.encodeCall(ISilo.leverageSameAsset, (depositAssets, ASSETS, BORROWER, ISilo.CollateralType.Collateral)),
            "LeverageSameAsset 1st (no interest)",
            303332
        );
    }
}
