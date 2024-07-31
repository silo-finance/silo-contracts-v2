// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {SiloLittleHelper} from  "../_common/SiloLittleHelper.sol";

/*
FOUNDRY_PROFILE=core-test forge test --ffi -vv --mc ShareCollateralTokenTest
*/
contract ShareCollateralTokenTest is Test, SiloLittleHelper {
    ISiloConfig public siloConfig;
    ShareCollateralToken public shareCollateralToken0;
    ShareCollateralToken public shareProtectedToken0;
    ShareCollateralToken public shareCollateralToken1;
    ShareCollateralToken public shareProtectedToken1;

    address immutable depositor;
    address immutable receiver;

    constructor() {
        depositor = makeAddr("depositor");
        receiver = makeAddr("receiver");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();
        (address protectedShareToken, address collateralShareToken, ) = siloConfig.getShareTokens(address(silo0));
        shareCollateralToken0 = ShareCollateralToken(collateralShareToken);
        shareProtectedToken0 = ShareCollateralToken(protectedShareToken);

        (protectedShareToken, collateralShareToken, ) = siloConfig.getShareTokens(address(silo1));
        shareCollateralToken1 = ShareCollateralToken(collateralShareToken);
        shareProtectedToken1 = ShareCollateralToken(protectedShareToken);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_sToken_transfer_zero_whenDeposit_
    */
    function test_sToken_transfer_zero_whenDeposit_collateral() public {
        _sToken_transfer_zero_whenDeposit(ISilo.CollateralType.Collateral);
    }

    function test_sToken_transfer_zero_whenDeposit_protected() public {
        _sToken_transfer_zero_whenDeposit(ISilo.CollateralType.Protected);
    }

    function _sToken_transfer_zero_whenDeposit(ISilo.CollateralType _collateralType) private {
        _deposit(100, depositor, _collateralType);

        vm.expectRevert(IShareToken.ZeroTransfer.selector);
        _token1(_collateralType).transfer(receiver, 0);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_sToken_transfer_whenDeposit_
    */
    function test_sToken_transfer_whenDeposits_collateral() public {
        _sToken_transfer_withDeposits(ISilo.CollateralType.Collateral);
    }

    function test_sToken_transfer_whenDeposits_protected() public {
        _sToken_transfer_withDeposits(ISilo.CollateralType.Protected);
    }

    function _sToken_transfer_withDeposits(ISilo.CollateralType _collateralType) private {
        _depositCollateral(100, depositor, SAME_ASSET, _collateralType);
        _depositCollateral(100, depositor, TWO_ASSETS, _collateralType);

        IShareToken token1 = _token1(_collateralType);

        vm.prank(depositor);
        token1.transfer(receiver, 1);

        assertEq(_token1(_collateralType).balanceOf(receiver), 1, "transfer success");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_sToken_transfer_whenSolvent_
    */
    function test_sToken_transfer_whenSolvent_collateral_1() public {
        _sToken_transfer_whenSolvent(ISilo.CollateralType.Collateral, SAME_ASSET);
    }

    function test_sToken_transfer_whenSolvent_collateral_2() public {
        _sToken_transfer_whenSolvent(ISilo.CollateralType.Collateral, TWO_ASSETS);
    }

    function test_sToken_transfer_whenSolvent_protected_1() public {
        _sToken_transfer_whenSolvent(ISilo.CollateralType.Protected, SAME_ASSET);
    }

    function test_sToken_transfer_whenSolvent_protected_2() public {
        _sToken_transfer_whenSolvent(ISilo.CollateralType.Protected, TWO_ASSETS);
    }

    function _sToken_transfer_whenSolvent(ISilo.CollateralType _collateralType, bool _sameAsset) private {
        _depositCollateral(100, depositor, SAME_ASSET, _collateralType);
        _depositCollateral(100, depositor, TWO_ASSETS, _collateralType);

        _depositForBorrow(10, makeAddr("any"));
        _borrow(1, depositor, _sameAsset);

        assertTrue(silo1.isSolvent(depositor), "expect solvent user");

        vm.startPrank(depositor);

        _token0(_collateralType).transfer(receiver, 1);
        assertEq(_token0(_collateralType).balanceOf(receiver), 1, "transfer0 success");

        _token1(_collateralType).transfer(receiver, 1);
        assertEq(_token1(_collateralType).balanceOf(receiver), 1, "transfer1 success");

        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_sToken_transfer_NotSolvent_
    */
    function test_sToken_transfer_NotSolvent_collateral_1() public {
        _sToken_transfer_NotSolvent(ISilo.CollateralType.Collateral, SAME_ASSET);
    }

    function test_sToken_transfer_NotSolvent_collateral_2() public {
        _sToken_transfer_NotSolvent(ISilo.CollateralType.Collateral, TWO_ASSETS);
    }

    function test_sToken_transfer_NotSolvent_protected_1() public {
        _sToken_transfer_NotSolvent(ISilo.CollateralType.Protected, SAME_ASSET);
    }

    function test_sToken_transfer_NotSolvent_protected_2() public {
        _sToken_transfer_NotSolvent(ISilo.CollateralType.Protected, TWO_ASSETS);
    }

    function _sToken_transfer_NotSolvent(ISilo.CollateralType _collateralType, bool _sameAsset) private {
        _depositCollateral(1e18, depositor, SAME_ASSET, _collateralType);
        _depositCollateral(1e18, depositor, TWO_ASSETS, _collateralType);

        _depositForBorrow(0.75e18, makeAddr("any"));
        _borrow(0.75e18, depositor, _sameAsset);

        vm.warp(block.timestamp + 20000 days);

        assertFalse(silo1.isSolvent(depositor), "expect NOT solvent user");

        IShareToken token0 = _token0(_collateralType);
        IShareToken token1 = _token1(_collateralType);

        vm.startPrank(depositor);

        if (_sameAsset) { // deposit is in silo0
            token0.transfer(receiver, 1);
            assertEq(token0.balanceOf(receiver), 1, "transfer0 success");

            vm.expectRevert(IShareToken.SenderNotSolventAfterTransfer.selector);
            token1.transfer(receiver, 1);
            assertEq(token1.balanceOf(receiver), 0, "transfer1 success");
        } else {
            vm.expectRevert(IShareToken.SenderNotSolventAfterTransfer.selector);
            token0.transfer(receiver, 1);
            assertEq(token0.balanceOf(receiver), 0, "transfer0 success");

            token1.transfer(receiver, 1);
            assertEq(token1.balanceOf(receiver), 1, "transfer1 success");
        }

        vm.stopPrank();
    }

    function _token0(ISilo.CollateralType _collateralType) private view returns (ShareCollateralToken) {
        return _collateralType == ISilo.CollateralType.Collateral ? shareCollateralToken0 : shareProtectedToken0;
    }

    function _token1(ISilo.CollateralType _collateralType) private view returns (ShareCollateralToken) {
        return _collateralType == ISilo.CollateralType.Collateral ? shareCollateralToken1 : shareProtectedToken1;
    }
}