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
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_maxWithdraw_usersDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_maxWithdraw_usersDuration0(uint256 _silos) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calulculations

        _convert(user, _silos);

        assertEq(
            xSilo.maxWithdraw(user),
            xSilo.getAmountByVestingDuration(xSilo.balanceOf(user), 0),
            "withdraw give us same result as redeem with 0 duration"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_maxRedeem_usersDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_maxRedeem_usersDuration0(uint256 _silos) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calulculations

        _convert(user, _silos);

        assertEq(
            xSilo.maxRedeem(user),
            xSilo.getXAmountByVestingDuration(xSilo.balanceOf(user), 0),
            "redeem give us same result as redeem with 0 duration"
        );
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
