// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

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
    function test_gas_leverageSameAsset() public {
        ISiloConfig.ConfigData memory config = ISiloConfig(silo1.config()).getConfig(address(silo1));

        uint256 transferDiff = (ASSETS * 1e18 / config.maxLtv) - ASSETS;
        token1.mint(BORROWER, transferDiff);

        vm.prank(BORROWER);
        token1.approve(address(silo1), transferDiff);

        _action(
            BORROWER,
            address(silo1),
            abi.encodeCall(ISilo.leverageSameAsset, (ASSETS, BORROWER, ISilo.AssetType.Collateral)),
            "LeverageSameAsset 1st (no interest)",
            235899
        );
    }
}
