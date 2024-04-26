// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {ConfigLib} from "silo-core/contracts/lib/ConfigLib.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc SwitchCollateralToTest
*/
contract SwitchCollateralToTest is SiloLittleHelper, Test {
    using ConfigLib for ISiloConfig;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_switchCollateralTo_pass_
    */
    function test_switchCollateralTo_pass_1token() public {
        _switchCollateralTo_pass(SAME_ASSET);
    }

    function test_switchCollateralTo_pass_2tokens() public {
        _switchCollateralTo_pass(TWO_ASSETS);
    }

    function _switchCollateralTo_pass(bool _sameAsset) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _depositCollateral(assets, borrower, _sameAsset);
        _depositCollateral(assets, borrower, !_sameAsset);
        _depositForBorrow(assets, depositor);

        _borrow(assets / 2, borrower, _sameAsset);

        (,, ISiloConfig.DebtInfo memory debtInfo) = siloConfig.pullConfigs(address(silo0), borrower, 0);
        assertEq(debtInfo.sameAsset, _sameAsset, "original position type");

        vm.prank(borrower);
        silo0.switchCollateralTo(!_sameAsset);
        (,, debtInfo) = siloConfig.pullConfigs(address(silo0), borrower, 0);

        assertEq(debtInfo.sameAsset, !_sameAsset, "position type after change");

        ISilo siloWithDeposit = _sameAsset ? silo1 : silo0;
        vm.prank(borrower);
        siloWithDeposit.withdraw(assets, borrower, borrower);

        assertGt(siloLens.getLtv(silo0, borrower), 0, "user has debt");
        assertTrue(silo0.isSolvent(borrower), "user is solvent");
    }

    /*
    forge test -vv --mt test_switchCollateralTo_NotSolvent_
    */
    function test_switchCollateralTo_NotSolvent_1token() public {
        _switchCollateralTo_NotSolvent(SAME_ASSET);
    }

    function test_switchCollateralTo_NotSolvent_2tokens() public {
        _switchCollateralTo_NotSolvent(TWO_ASSETS);
    }

    function _switchCollateralTo_NotSolvent(bool _sameAsset) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _depositCollateral(assets, borrower, _sameAsset);
        _depositCollateral(1, borrower, !_sameAsset);
        _depositForBorrow(assets, depositor);
        _borrow(assets / 2, borrower, _sameAsset);

        vm.prank(borrower);
        vm.expectRevert(ISilo.NotSolvent.selector);
        silo1.switchCollateralTo(!_sameAsset);
    }

    function test_switchCollateralTo_CollateralTypeDidNotChanged_1token() public {
        _switchCollateralTo_CollateralTypeDidNotChanged(SAME_ASSET);
    }

    function test_switchCollateralTo_CollateralTypeDidNotChanged_2tokens() public {
        _switchCollateralTo_CollateralTypeDidNotChanged(TWO_ASSETS);
    }

    function _switchCollateralTo_CollateralTypeDidNotChanged(bool _sameAsset) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _depositCollateral(assets, borrower, _sameAsset);
        _depositCollateral(assets, borrower, !_sameAsset);

        _depositForBorrow(assets, depositor);
        _borrow(assets / 2, borrower, _sameAsset);

        vm.prank(borrower);
        vm.expectRevert(ISiloConfig.CollateralTypeDidNotChanged.selector);
        silo0.switchCollateralTo(_sameAsset);
    }

    function test_switchCollateralTo_NoDebt_1token() public {
        _switchCollateralTo_NoDebt(SAME_ASSET);
    }

    function test_switchCollateralTo_NoDebt_2tokens() public {
        _switchCollateralTo_NoDebt(TWO_ASSETS);
    }

    function _switchCollateralTo_NoDebt(bool _sameAsset) private {
        address borrower = makeAddr("Borrower");

        vm.prank(borrower);
        vm.expectRevert(ISiloConfig.NoDebt.selector);
        silo0.switchCollateralTo(_sameAsset);
    }
}
