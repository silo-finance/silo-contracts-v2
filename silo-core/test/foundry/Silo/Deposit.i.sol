// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import "../_common/fixtures/SiloFixture_ETH_USDC.sol";

contract DepositTest is IntegrationTest {
    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;

    TokenMock weth;
    TokenMock usdc;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

        SiloFixture_ETH_USDC siloFixture = new SiloFixture_ETH_USDC();
        (siloConfig, silo0, silo1, weth, usdc) = siloFixture.deploy(vm);
    }

    /*
    forge test -vv --mt test_deposit_gas
    */
    function test_deposit_gas() public {
        uint256 assets = 1e18;
        address depositor = address(10);
        address borrower = address(11);

        weth.transferFromMock(address(this), address(silo0), assets);
        uint256 gasStart = gasleft();
        silo0.deposit(assets, depositor);
        uint256 gasEnd = gasleft();

        // assertEq(gasStart - gasEnd, 144471, "optimise deposit");

        weth.transferFromMock(address(silo0), depositor, assets / 2);
        gasStart = gasleft();
        vm.prank(depositor);
        silo0.withdraw(assets / 2, depositor, depositor);
        gasEnd = gasleft();
        // assertEq(gasStart - gasEnd, 80541, "optimise withdraw");

        weth.transferFromMock(depositor, address(silo0), assets);
        vm.prank(depositor);
        silo0.deposit(assets, depositor);

        usdc.transferFromMock(borrower, address(silo1), assets * 2);
        vm.prank(borrower);
        silo1.deposit(assets * 2, borrower);

        weth.transferFromMock(address(silo0), borrower, assets / 2);
        gasStart = gasleft();
        vm.prank(borrower);
        silo0.borrow(assets / 2, borrower, borrower);
        gasEnd = gasleft();
        // assertEq(gasStart - gasEnd, 134221, "optimise borrow");

        weth.transferFromMock(borrower, address(silo0), assets / 2);
        gasStart = gasleft();
        vm.prank(borrower);
        silo0.repay(assets / 2, borrower);
        gasEnd = gasleft();
        // assertEq(gasStart - gasEnd, 28401, "optimise repay");
    }
}
