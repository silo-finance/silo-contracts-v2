// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

contract DepositTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    MintableToken weth;
    MintableToken usdc;

    function setUp() public {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        __init(vm, token0, token1, silo0, silo1);

        weth = token0;
        usdc = token1;
    }

    /*
    forge test -vv --mt test_deposit_gas
    */
    function test_deposit_gas() public {
        uint256 assets = 1e18;
        address depositor = address(10);
        address borrower = address(11);

        uint256 gasStart = gasleft();
        _deposit(assets, depositor);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 257898, "optimise deposit");

        gasStart = gasleft();
        _withdraw(assets / 2, depositor);
        gasEnd = gasleft();
        // assertEq(gasStart - gasEnd, 80541, "optimise withdraw");

        _depositForBorrow(assets, depositor);

        _deposit(assets * 2, borrower);

        gasStart = gasleft();
        _borrow(assets / 2, borrower);
        gasEnd = gasleft();
        // assertEq(gasStart - gasEnd, 134221, "optimise borrow");

        vm.prank(borrower);
        usdc.approve(address(silo1), assets / 2);
        gasStart = gasleft();
        vm.prank(borrower);
        silo1.repay(assets / 2, borrower);
        gasEnd = gasleft();
        // assertEq(gasStart - gasEnd, 28401, "optimise repay");
    }
}
