// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

contract DepositTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    MintableToken weth;
    MintableToken usdc;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);


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
    forge test -vv --ffi --mt test_deposit_revertsZeroAssets
    */
    function test_deposit_revertsZeroAssets() public {
        uint256 _assets;
        ISilo.AssetType _type;
        address _depositor = makeAddr("Depositor");

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.deposit(_assets, _depositor);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.deposit(_assets, _depositor, _type);
    }

    /*
    forge test -vv --ffi --mt test_deposit_reverts_WrongAssetType
    */
    function test_deposit_reverts_WrongAssetType() public {
        uint256 _assets = 1;
        ISilo.AssetType _type = ISilo.AssetType.Debt;
        address _depositor = makeAddr("Depositor");

        vm.expectRevert(ISilo.WrongAssetType.selector);
        silo0.deposit(_assets, _depositor, _type);
    }

    /*
    forge test -vv --ffi --mt test_deposit_everywhere
    */
    function test_deposit_everywhere() public {
        uint256 assets = 1;
        address depositor = makeAddr("Depositor");

        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Protected);

        (ISiloConfig.ConfigData memory collateral, ISiloConfig.ConfigData memory debt) = siloConfig.getConfigs(address(silo0));

        assertEq(token0.balanceOf(address(silo0)), assets * 2);
        assertEq(silo0.getCollateralAssets(), assets);
        assertEq(silo0.getProtectedAssets(), assets);
        assertEq(silo0.getDebtAssets(), 0);

        assertEq(IShareToken(collateral.collateralShareToken).balanceOf(depositor), assets, "collateral shares");
        assertEq(IShareToken(collateral.protectedShareToken).balanceOf(depositor), assets, "protected shares");

        assertEq(token1.balanceOf(address(silo1)), assets * 2);
        assertEq(silo1.getCollateralAssets(), assets);
        assertEq(silo1.getProtectedAssets(), assets);
        assertEq(silo1.getDebtAssets(), 0);

        assertEq(IShareToken(debt.collateralShareToken).balanceOf(depositor), assets, "collateral shares (on other silo)");
        assertEq(IShareToken(debt.protectedShareToken).balanceOf(depositor), assets, "protected shares (on other silo)");
    }

    /*
    forge test -vv --ffi --mt test_deposit_toWrongSilo
    */
    function test_deposit_toWrongSilo() public {
        uint256 assets = 1;
        address depositor = makeAddr("Depositor");

        vm.prank(depositor);
        token1.approve(address(silo0), assets);
        vm.prank(depositor);
        vm.expectRevert("ERC20: insufficient allowance");
        silo0.deposit(assets, depositor, ISilo.AssetType.Collateral);
    }

    /*
    forge test -vv --ffi --mt test_deposit_emitEvents
    */
    function test_deposit_emitEvents() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        token0.mint(depositor, assets * 2);
        vm.prank(depositor);
        token0.approve(address(silo0), assets * 2);

        vm.expectEmit(true, true, true, true);
        emit Deposit(depositor, depositor, assets, assets);

        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.AssetType.Collateral);

        vm.expectEmit(true, true, true, true);
        emit DepositProtected(depositor, depositor, assets, assets);

        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.AssetType.Protected);
    }
}
