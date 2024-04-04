// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract BorrowFast1stGasTest is Gas, Test {
    function setUp() public {
        _gasTestsInit();

    }

    /*
    forge test -vv --ffi --mt test_gas_fastBorrow
    */
    function test_gas_fastBorrow() public {
        ISiloConfig.ConfigData memory config = ISiloConfig(silo1.config()).getConfig(address(silo1));

        uint256 transferDiff = (ASSETS * 1e18 / config.maxLtv) - ASSETS;

        vm.prank(BORROWER);
        token1.approve(address(silo1), transferDiff);
        token1.mint(BORROWER, transferDiff);

        _action(
            BORROWER,
            address(silo1),
            abi.encodeCall(ISilo.fastBorrow, (ASSETS, BORROWER, ISilo.AssetType.Collateral)),
            "BorrowFast 1st (no interest)",
            235899
        );
    }
}
