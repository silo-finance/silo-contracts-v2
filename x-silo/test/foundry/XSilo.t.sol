// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {XSiloAndStreamDeploy} from "x-silo/deploy/XSiloAndStreamDeploy.s.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {XSilo, XRedeemPolicy, Stream, ERC20} from "../../contracts/XSilo.sol";

/*
FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mc XSiloTest
*/
contract XSiloTest is Test {
    Stream stream;
    XSilo xSilo;
    ERC20Mock asset;

    address user = makeAddr("user");

    function setUp() public {
        AddrLib.init();

        asset = new ERC20Mock();

        AddrLib.setAddress(AddrKey.SILO_TOKEN_V2, address(asset));
        AddrLib.setAddress(AddrKey.DAO, address(this));

        XSiloAndStreamDeploy deploy = new XSiloAndStreamDeploy();
        deploy.disableDeploymentsSync();
        (xSilo, stream) = deploy.run();
        // all tests are done for this setup:

        assertEq(xSilo.minRedeemRatio(), 0.5e2, "expected initial setup for minRedeemRatio");
        assertEq(xSilo.maxRedeemRatio(), 1e2, "expected initial setup for maxRedeemRatio");
        assertEq(xSilo.minRedeemDuration(), 0, "expected initial setup for minRedeemDuration");
        assertEq(xSilo.maxRedeemDuration(), 6 * 30 days, "expected initial setup for maxRedeemDuration");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_SelfTransferNotAllowed
    */
    function test_SelfTransferNotAllowed() public {
        _convert(address(this), 10);

        vm.expectRevert(XSilo.SelfTransferNotAllowed.selector);
        xSilo.transfer(address(this), 1);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeem_usesDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_redeem_usesDuration0(uint256 _silos, uint256 _xSiloToRedeem) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation
        vm.assume(_xSiloToRedeem > 0);

        _convert(user, _silos);
        vm.assume(_xSiloToRedeem <= xSilo.balanceOf(user));

        uint256 expectedAmountOut = xSilo.getAmountByVestingDuration(_xSiloToRedeem, 0);
        vm.assume(expectedAmountOut > 0);

        vm.startPrank(user);

        assertEq(
            xSilo.redeem(_xSiloToRedeem, user, user),
            expectedAmountOut,
            "withdraw give us same result as redeem with 0 duration"
        );

        assertEq(asset.balanceOf(user), expectedAmountOut, "user got exact amount of tokens");

        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_maxWithdraw_usersDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_maxWithdraw_usersDuration0(uint256 _silos) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        _convert(user, _silos);

        assertEq(
            xSilo.maxWithdraw(user),
            xSilo.getAmountByVestingDuration(xSilo.balanceOf(user), 0),
            "withdraw give us same result as redeem with 0 duration"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_previewWithdraw_usersDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_previewWithdraw_usersDuration0(uint256 _silos) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        uint256 xSiloRequiredFor = xSilo.previewWithdraw(_silos);

        assertEq(
            xSilo.getAmountByVestingDuration(xSiloRequiredFor, 0),
            _silos,
            "previewWithdraw give us same result as vesting with 0 duration"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_maxRedeem_usersDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_maxRedeem_usersDuration0(uint256 _silos) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        _convert(user, _silos);

        assertEq(
            xSilo.maxRedeem(user),
            xSilo.getXAmountByVestingDuration(xSilo.balanceOf(user), 0),
            "redeem give us same result as redeem with 0 duration"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_previewRedeem_usersDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_previewRedeem_usersDuration0(uint256 _xSilos) public {
        vm.assume(_xSilos > 0);

        assertEq(
            xSilo.previewRedeem(_xSilos),
            xSilo.getAmountByVestingDuration(_xSilos, 0),
            "previewRedeem give us same result as vesting with 0 duration"
        );
    }


    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_withdraw_usesDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_withdraw_usesDuration0(uint256 _silos, uint256 _siloToWithdraw) public {
//        uint256 _silos = 100; uint256 _siloToWithdraw = 15;

        vm.assume(_silos > 0);
        vm.assume(_siloToWithdraw > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        _convert(user, _silos);
        vm.assume(_siloToWithdraw <= xSilo.maxWithdraw(user));

        vm.startPrank(user);

        uint256 checkpoint = vm.snapshot();
        uint256 withdrawnShares = xSilo.withdraw(_siloToWithdraw, user, user);

        assertEq(asset.balanceOf(user), _siloToWithdraw, "user got exact amount of tokens");

        vm.revertTo(checkpoint);

        emit log_named_uint("withdrawnShares after rollback", withdrawnShares);
        emit log_named_uint("_siloToWithdraw", _siloToWithdraw);

        vm.startPrank(user);

        assertEq(
            _siloToWithdraw,
            xSilo.getAmountByVestingDuration(withdrawnShares, 0),
            "withdraw give us same result as vesting with 0 duration"
        );

        vm.stopPrank();
    }

    function _convert(address _user, uint256 _amount) public returns (uint256 shares){
        vm.startPrank(_user);

        asset.mint(_user, _amount);
        asset.approve(address(xSilo), _amount);
        shares = xSilo.deposit(_amount, _user);

        assertGt(shares, 0, "[_convert] shares received");

        vm.stopPrank();
    }
}
