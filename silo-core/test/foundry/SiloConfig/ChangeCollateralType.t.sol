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
        (address silo0, address silo1) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory collateral = siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory debt = siloConfig.getConfig(silo1);

        _changeCollateralType_reverts_OnlySilo_From(collateral.collateralShareToken);
        _changeCollateralType_reverts_OnlySilo_From(collateral.protectedShareToken);
        _changeCollateralType_reverts_OnlySilo_From(collateral.debtShareToken);

        _changeCollateralType_reverts_OnlySilo_From(debt.collateralShareToken);
        _changeCollateralType_reverts_OnlySilo_From(debt.protectedShareToken);
        _changeCollateralType_reverts_OnlySilo_From(debt.debtShareToken);

        _changeCollateralType_reverts_OnlySilo_From(address(0));
    }

    function _changeCollateralType_reverts_OnlySilo_From(address _from) private {
        vm.expectRevert(ISiloConfig.OnlySilo.selector);
        vm.prank(_from);
        siloConfig.switchCollateralSilo(borrower);
    }

    /*
    forge test -vv --ffi --mt test_changeCollateralType_pass_1token
    */
    function test_changeCollateralType_pass_1token() public {
        uint256 assets = 1e18;

        _deposit(assets, borrower);
        _depositForBorrow(assets, borrower);
        _depositForBorrow(assets, makeAddr("Depositor"));

        _borrow(assets / 2, borrower);

        vm.prank(address(silo0));
        siloConfig.switchCollateralSilo(borrower);

        ISiloConfig.ConfigData memory collateral;
        ISiloConfig.ConfigData memory debt;

        (collateral, debt) = siloConfig.getConfigs(borrower);

        assertTrue(debt.silo == collateral.silo);
    }

    /*
    forge test -vv --ffi --mt test_changeCollateralType_NoDebt
    */
    function test_changeCollateralType_NoDebt() public {
        _doDeposit(false);

        vm.prank(address(silo0));
        vm.expectRevert(ISiloConfig.NoDebt.selector);

        siloConfig.switchCollateralSilo(borrower);
    }

    function _doDeposit() private returns (ISiloConfig.ConfigData memory collateral, ISiloConfig.ConfigData memory debt) {
        return _doDeposit(true);
    }

    function _doDeposit(bool _andBorrow)
        private
        returns (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        )
    {
        _deposit(100, borrower);
        _deposit(2, borrower);

        if (_andBorrow) _borrow(1, borrower);

        (collateral, debt) = siloConfig.getConfigs(borrower);
    }
}
