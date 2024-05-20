// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
forge test -vv --ffi --mc ChangeCollateralTypeTest
*/
contract ChangeCollateralTypeTest is SiloLittleHelper, Test {
    address immutable borrower;
    ISiloConfig siloConfig;

    constructor() {
        borrower = makeAddr("borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_changeCollateralType_reverts_OnlySilo
    */
    function test_changeCollateralType_reverts_OnlySilo_1token() public {
        _changeCollateralType_reverts_OnlySilo(SAME_ASSET);
    }

    function test_changeCollateralType_reverts_OnlySilo_2tokens() public {
        _changeCollateralType_reverts_OnlySilo(TWO_ASSETS);
    }

    function _changeCollateralType_reverts_OnlySilo(bool _toSameAsset) private {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
        ) = siloConfig.getConfigs(address(silo0), address(0), 0);

        _changeCollateralType_reverts_OnlySilo_From(collateral.collateralShareToken, _toSameAsset);
        _changeCollateralType_reverts_OnlySilo_From(collateral.protectedShareToken, _toSameAsset);
        _changeCollateralType_reverts_OnlySilo_From(collateral.debtShareToken, _toSameAsset);

        _changeCollateralType_reverts_OnlySilo_From(debt.collateralShareToken, _toSameAsset);
        _changeCollateralType_reverts_OnlySilo_From(debt.protectedShareToken, _toSameAsset);
        _changeCollateralType_reverts_OnlySilo_From(debt.debtShareToken, _toSameAsset);

        _changeCollateralType_reverts_OnlySilo_From(address(0), _toSameAsset);
    }

    function _changeCollateralType_reverts_OnlySilo_From(address _from, bool _toSameAsset) private {
        _doDeposit(!_toSameAsset);

        vm.expectRevert(ISiloConfig.OnlySilo.selector);
        vm.prank(_from);
        siloConfig.accrueInterestAndGetConfigs(
            address(silo0), borrower, Hook.SWITCH_COLLATERAL | (_toSameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );
    }

    /*
    forge test -vv --ffi --mt test_changeCollateralType_pass
    */
    function test_changeCollateralType_pass_1token() public {
        _changeCollateralType_pass(SAME_ASSET);
    }

    function test_changeCollateralType_pass_2tokens() public {
        _changeCollateralType_pass(TWO_ASSETS);
    }

    function _changeCollateralType_pass(bool _toSameAsset) private {
        ISiloConfig.DebtInfo memory debtInfo = _doDeposit(!_toSameAsset);

        assertEq(debtInfo.sameAsset, !_toSameAsset);

        vm.prank(address(silo0));
        (,, debtInfo) = siloConfig.accrueInterestAndGetConfigs(
            address(silo0), borrower, Hook.SWITCH_COLLATERAL | (_toSameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );

        assertEq(debtInfo.sameAsset, _toSameAsset);

        vm.prank(address(silo0));
        siloConfig.crossNonReentrantAfter();

        vm.prank(address(silo1));
        (,, debtInfo) = siloConfig.accrueInterestAndGetConfigs(
            address(silo0), borrower, Hook.SWITCH_COLLATERAL | (!_toSameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );

        assertEq(debtInfo.sameAsset, !_toSameAsset);
    }

    /*
    forge test -vv --ffi --mt test_changeCollateralType_CollateralTypeDidNotChanged_
    */
    function test_changeCollateralType_CollateralTypeDidNotChanged_1token() public {
        _changeCollateralType_CollateralTypeDidNotChanged(SAME_ASSET);
    }

    function test_changeCollateralType_CollateralTypeDidNotChanged_2tokens() public {
        _changeCollateralType_CollateralTypeDidNotChanged(TWO_ASSETS);
    }

    function _changeCollateralType_CollateralTypeDidNotChanged(bool _toSameAsset) private {
        _doDeposit(_toSameAsset);

        vm.prank(address(silo0));
        vm.expectRevert(ISiloConfig.CollateralTypeDidNotChanged.selector);

        siloConfig.accrueInterestAndGetConfigs(
            address(silo0), borrower, Hook.SWITCH_COLLATERAL | (_toSameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );
    }

    /*
    forge test -vv --ffi --mt test_changeCollateralType_pass
    */
    function test_changeCollateralType_NoDebt() public {
        _doDeposit(SAME_ASSET, false);

        vm.prank(address(silo0));
        vm.expectRevert(ISiloConfig.NoDebt.selector);

        siloConfig.accrueInterestAndGetConfigs(
            address(silo0), borrower, Hook.SWITCH_COLLATERAL | (SAME_ASSET ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );
    }

    function _doDeposit(bool _sameAsset) private returns (ISiloConfig.DebtInfo memory debtInfo) {
        return _doDeposit(_sameAsset, true);
    }

    function _doDeposit(bool _sameAsset, bool _andBorrow) private returns (ISiloConfig.DebtInfo memory debtInfo) {
        _depositCollateral(100, borrower, _sameAsset);
        _depositCollateral(2, borrower, !_sameAsset);

        if (_andBorrow) _borrow(1, borrower, _sameAsset);

        (,, debtInfo) = siloConfig.getConfigs(address(silo0), borrower, 0);
    }
}
