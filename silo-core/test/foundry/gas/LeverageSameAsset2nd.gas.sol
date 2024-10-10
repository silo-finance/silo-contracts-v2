// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]' | sort
*/
contract LeverageSameAsset2ndGasTest is Gas, Test {
    function setUp() public {
        _gasTestsInit();

        bool toSilo1 = true;

        _depositCollateral(ASSETS * 10, BORROWER, toSilo1);
        _depositCollateral(ASSETS * 10, BORROWER, !toSilo1);
        _borrow(ASSETS, BORROWER);
    }

    function test_gas_leverageSameAsset2nd() public {
        token1.mint(BORROWER, ASSETS);

        vm.prank(BORROWER);
        token1.approve(address(silo1), ASSETS);

        uint256 depositAssets = ASSETS * 2;

        _action(
            BORROWER,
            address(silo1),
            abi.encodeCall(ISilo.leverageSameAsset, (depositAssets, ASSETS, BORROWER, ISilo.CollateralType.Collateral)),
            "LeverageSameAsset 2nd (no interest)",
            145141
        );
    }
}
