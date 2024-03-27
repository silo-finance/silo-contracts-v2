// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc DepositTest
*/
contract DepositTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    MintableToken weth;
    MintableToken usdc;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    function setUp() public {
        siloConfig = _setUpLocalFixture();

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

        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
        ) = siloConfig.getConfigs(address(silo0), address(0));

        assertEq(token0.balanceOf(address(silo0)), assets * 2);
        assertEq(silo0.getCollateralAssets(), assets);
        assertEq(silo0.total(ISilo.AssetType.Protected), assets);
        assertEq(silo0.getDebtAssets(), 0);

        assertEq(IShareToken(collateral.collateralShareToken).balanceOf(depositor), assets, "collateral shares");
        assertEq(IShareToken(collateral.protectedShareToken).balanceOf(depositor), assets, "protected shares");

        assertEq(token1.balanceOf(address(silo1)), assets * 2);
        assertEq(silo1.getCollateralAssets(), assets);
        assertEq(silo1.total(ISilo.AssetType.Protected), assets);
        assertEq(silo1.getDebtAssets(), 0);

        assertEq(IShareToken(debt.collateralShareToken).balanceOf(depositor), assets, "collateral shares (on other silo)");
        assertEq(IShareToken(debt.protectedShareToken).balanceOf(depositor), assets, "protected shares (on other silo)");
    }

    /*
    forge test -vv --ffi --mt test_deposit_withDebt_2tokens
    */
    function test_deposit_withDebt_2tokens() public {
        _deposit_withDebt(false);
    }

    /*
    forge test -vv --ffi --mt test_deposit_withDebt_1token
    */
    function test_deposit_withDebt_1token() public {
        _deposit_withDebt(true);
    }

    function _deposit_withDebt(bool _sameToken) internal {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Protected);

        uint256 maxBorrow = silo1.maxBorrow(depositor, _sameToken);
        _borrow(maxBorrow, depositor, _sameToken);

        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Protected);
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

    /*
    forge test -vv --ffi --mt test_deposit_totalAssets
    */
    function test_deposit_totalAssets() public {
        _deposit(123, makeAddr("Depositor"));

        assertEq(silo0.totalAssets(), 123, "totalAssets 0");
        assertEq(silo1.totalAssets(), 0, "totalAssets 1");
    }

    /*
    forge test -vv --ffi --mt test_deposit_revert_zeroShares
    */
    function test_deposit_revert_zeroShares_1token() public {
        _deposit_revert_zeroShares(true);
    }

    function test_deposit_revert_zeroShares_2tokens() public {
        _deposit_revert_zeroShares(false);
    }

    function _deposit_revert_zeroShares(bool _sameToken) private {
        address borrower = makeAddr("borrower");

        _createCollateral(2 ** 128, borrower, _sameToken);
        _depositForBorrow(2 ** 128, address(2));

        _borrow(2 ** 128 / 2, borrower, _sameToken);

        address anyAddress = makeAddr("any");
        // no interest, so shares are 1:1
        _depositForBorrow(1, anyAddress);

        vm.warp(block.timestamp + 365 days);

        // with interest assets > shares, so we can get zero

        _mintTokens(token1, 1, anyAddress);

        vm.startPrank(anyAddress);
        token1.approve(address(silo1), 1);
        vm.expectRevert(ISilo.ZeroShares.selector);
        silo1.deposit(1, anyAddress);
        vm.stopPrank();
    }
}
