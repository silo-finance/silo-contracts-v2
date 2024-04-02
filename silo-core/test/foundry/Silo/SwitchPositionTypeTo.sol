// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

contract SwitchPositionTypeTo is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_switchPositionTypeTo_pass_1token
    */
    function test_switchPositionTypeTo_pass_1token() public {
        _switchPositionTypeTo_pass(true);
    }

    function test_switchPositionTypeTo_pass_2tokens() public {
        _switchPositionTypeTo_pass(false);
    }

    function _switchPositionTypeTo_pass(bool _sameToken) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _depositCollateral(assets, borrower, _sameToken);
        _depositCollateral(assets, borrower, !_sameToken);

        _depositForBorrow(assets, depositor);

        _borrow(assets / 2, borrower, _sameToken);

        (,, ISiloConfig.PositionInfo memory positionInfo) = siloConfig.getConfigs(address(silo0), borrower);
        assertEq(positionInfo.oneTokenPosition, _sameToken, "original position type");

        vm.prank(borrower);
        silo0.switchPositionTypeTo(!_sameToken);

        (,, positionInfo) = siloConfig.getConfigs(address(silo0), borrower);
        assertEq(positionInfo.oneTokenPosition, !_sameToken, "position type after change");

        ISilo siloWithDeposit = _sameToken ? silo0 : silo1;
        siloWithDeposit.withdraw(assets, borrower, borrower);
    }

    function test_switchPositionTypeTo_NotSolvent_1token() public {
        _switchPositionTypeTo_NotSolvent(true);
    }

    function test_switchPositionTypeTo_NotSolvent_2tokens() public {
        _switchPositionTypeTo_NotSolvent(false);
    }

    function _switchPositionTypeTo_NotSolvent(bool _sameToken) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _depositCollateral(assets, borrower, _sameToken);
        _depositForBorrow(assets, depositor);

        _borrow(assets / 2, borrower, _sameToken);

        vm.prank(borrower);
        vm.expectRevert(ISilo.NotSolvent.selector);
        silo0.switchPositionTypeTo(!_sameToken);
    }

    function test_switchPositionTypeTo_PositionDidNotChanged_1token() public {
        _switchPositionTypeTo_PositionDidNotChanged(true);
    }

    function test_switchPositionTypeTo_PositionDidNotChanged_2tokens() public {
        _switchPositionTypeTo_PositionDidNotChanged(false);
    }

    function _switchPositionTypeTo_PositionDidNotChanged(bool _sameToken) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _depositCollateral(assets, borrower, _sameToken);
        _depositCollateral(assets, borrower, !_sameToken);

        _depositForBorrow(assets, depositor);
        _borrow(assets / 2, borrower, _sameToken);

        vm.prank(borrower);
        vm.expectRevert(ISilo.PositionDidNotChanged.selector);
        silo0.switchPositionTypeTo(_sameToken);
    }

    function test_switchPositionTypeTo_PositionNotOpen_1token() public {
        _switchPositionTypeTo_PositionNotOpen(true);
    }

    function test_switchPositionTypeTo_PositionNotOpen_2tokens() public {
        _switchPositionTypeTo_PositionNotOpen(false);
    }

    function _switchPositionTypeTo_PositionNotOpen(bool _sameToken) private {
        address borrower = makeAddr("Borrower");

        vm.prank(borrower);
        vm.expectRevert(ISilo.PositionNotOpen.selector);
        silo0.switchPositionTypeTo(_sameToken);
    }
}
