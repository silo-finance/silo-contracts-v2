// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {OracleConfig} from "silo-oracles/deploy/OraclesDeployments.sol";
import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";

/*
    forge test -vv --mc WithdrawWhenNoDepositTest
*/
contract WithdrawWhenNoDepositTest is IntegrationTest {
    uint256 internal constant _BASIS_POINTS = 1e4;
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;

    TokenMock token0;
    TokenMock token1;

    function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, makeAddr("Timelock"));
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));

        SiloFixture siloFixture = new SiloFixture();
        address t0;
        address t1;
        (siloConfig, silo0, silo1, t0, t1) = siloFixture.deploy_ETH_USDC();

        token0 = new TokenMock(vm, t0);
        token1 = new TokenMock(vm, t1);
    }

    /*
    forge test -vv --mt test_withdraw_zeros
    */
    function test_withdraw_zeros() public {
        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(0, address(0), address(0));
    }

    /*
    forge test -vv --mt test_withdraw_WrongAssetType
    */
    function test_withdraw_WrongAssetType() public {
        vm.expectRevert(ISilo.WrongAssetType.selector);
        silo0.withdraw(0, address(1), address(1), ISilo.AssetType.Debt);
    }

    /*
    forge test -vv --mt test_withdraw_NothingToWithdraw
    */
    function test_withdraw_NothingToWithdraw() public {
        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(0, address(this), address(this), ISilo.AssetType.Collateral);

        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(0, address(this), address(this), ISilo.AssetType.Protected);

        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(1, address(this), address(this), ISilo.AssetType.Collateral);

        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(1, address(this), address(this), ISilo.AssetType.Protected);
    }

    /*
    forge test -vv --mt test_withdraw_when_liquidity_but_NothingToWithdraw
    */
    function test_withdraw_when_liquidity_but_NothingToWithdraw() public {
        // any deposit so we have liquidity
        _anyDeposit(ISilo.AssetType.Collateral);

        // test
        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(0, address(this), address(this), ISilo.AssetType.Collateral);

        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(0, address(this), address(this), ISilo.AssetType.Protected);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        silo0.withdraw(1, address(this), address(this), ISilo.AssetType.Collateral);

        vm.expectRevert(ISilo.NothingToWithdraw.selector);
        silo0.withdraw(1, address(this), address(this), ISilo.AssetType.Protected);

        // any deposit so we have liquidity
        _anyDeposit(ISilo.AssetType.Protected);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        silo0.withdraw(1, address(this), address(this), ISilo.AssetType.Protected);
    }

    function _anyDeposit(ISilo.AssetType _type) public {
        address otherDepositor = address(1);
        uint256 depositAmount = 1e18;

        token0.transferFromMock(otherDepositor, address(silo0), depositAmount);
        vm.prank(otherDepositor);
        silo0.deposit(depositAmount, otherDepositor, _type);
    }
}
