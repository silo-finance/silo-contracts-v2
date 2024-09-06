// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract TransferCollateralTest is Gas, Test {
    function setUp() public {
        _gasTestsInit();

        _depositCollateral(ASSETS * 2, BORROWER, TWO_ASSETS);
        _depositForBorrow(ASSETS, DEPOSITOR);
        _borrow(ASSETS, BORROWER, TWO_ASSETS);
    }

    /*
    forge test -vv --ffi --mt test_gas_transferCollateral
    */
    function test_gas_transferCollateral() public {
        (, address collateralShareToken, ) = ISiloConfig(silo0.config()).getShareTokens(address(silo0));

        _action(
            BORROWER,
            address(collateralShareToken),
            abi.encodeCall(IERC20.transfer, (BORROWER, 1)),
            "TransferCollateral (when debt)",
            146908
        );
    }
}
