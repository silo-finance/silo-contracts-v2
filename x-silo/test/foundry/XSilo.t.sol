// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

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
    uint256 internal constant _PRECISION = 100;

    Stream stream;
    XSilo xSilo;
    ERC20Mock asset;

    struct CustomSetup {
        uint64 minRedeemRatio;
        uint64 maxRedeemRatio;
        uint64 minRedeemDuration;
        uint64 maxRedeemDuration;
    }

    function setUp() public {
        AddrLib.init();

        asset = new ERC20Mock();

        AddrLib.setAddress(AddrKey.SILO_TOKEN_V2, address(asset));
        AddrLib.setAddress(AddrKey.DAO, address(this));

        XSiloAndStreamDeploy deploy = new XSiloAndStreamDeploy();
        deploy.disableDeploymentsSync();
        (xSilo, stream) = deploy.run();
        // all tests are done for this setup:

        _defaultSetupVerification();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_SelfTransferNotAllowed
    */
    function test_SelfTransferNotAllowed(CustomSetup memory _customSetup) public {
        _assumeCustomSetup(_customSetup);

        _convert(address(this), 10);

        vm.expectRevert(XSilo.SelfTransferNotAllowed.selector);
        xSilo.transfer(address(this), 1);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_transferFrom_success
    */
    function test_transferFrom_success(CustomSetup memory _customSetup) public {
        _assumeCustomSetup(_customSetup);

        address user = makeAddr("user");
        address spender = makeAddr("spender");

        uint256 xSiloAmount = 10e18;

        _convert(user, xSiloAmount);

        vm.prank(user);
        xSilo.approve(spender, xSiloAmount);

        assertEq(xSilo.balanceOf(user), xSiloAmount, "user balance should be xSiloAmount");
        assertEq(xSilo.balanceOf(spender), 0, "spender balance should be 0");

        vm.prank(spender);
        xSilo.transferFrom(user, spender, xSiloAmount);

        assertEq(xSilo.balanceOf(user), 0, "user balance should be 0");
        assertEq(xSilo.balanceOf(spender), xSiloAmount, "spender balance should be xSiloAmount");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_maxWithdraw_usersDuration0_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_maxWithdraw_usersDuration0_fuzz(CustomSetup memory _customSetup, uint256 _assets) public {
        _assumeCustomSetup(_customSetup);

        vm.assume(_assets > 0);
        vm.assume(_assets < type(uint256).max / 100); // to not cause overflow on calculation

        address user = makeAddr("user");

        _convert(user, _assets);

        assertEq(
            xSilo.maxWithdraw(user),
            xSilo.getAmountByVestingDuration(xSilo.balanceOf(user), 0),
            "withdraw give us same result as redeem with 0 duration"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_previewWithdraw_usersDuration0_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_previewWithdraw_usersDuration0_fuzz(
        CustomSetup memory _customSetup,
        uint256 _assets
    ) public {
        _assumeCustomSetup(_customSetup);

        vm.assume(_assets > 0);
        vm.assume(_assets < type(uint256).max / 100); // to not cause overflow on calculation

        uint256 xSiloRequiredForAssets = xSilo.previewWithdraw(_assets);
        emit log_named_uint("xSiloRequiredForAssets", xSiloRequiredForAssets);

        if (xSiloRequiredForAssets == type(uint256).max) {
            assertEq(
                xSilo.getAmountByVestingDuration(type(uint256).max, 0),
                0,
                "(ratio is 0) previewWithdraw give us MAX, because there are no amount that can withdraw even 1 wei"
            );
        } else {
            assertEq(
                xSilo.getAmountByVestingDuration(xSiloRequiredForAssets, 0),
                _assets,
                "previewWithdraw give us same result as vesting with 0 duration"
            );
        }
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_maxRedeem_returnsAll_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_maxRedeem_returnsAll_fuzz(CustomSetup memory _customSetup, uint256 _silos) public {
        _assumeCustomSetup(_customSetup);

        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        address user = makeAddr("user");

        _convert(user, _silos);

        assertEq(
            xSilo.maxRedeem(user),
            xSilo.balanceOf(user),
            "max redeem return all user balance even if not all can be translated immediatly to Silo"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_previewRedeem_usersDuration0_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_previewRedeem_usersDuration0_fuzz(CustomSetup memory _customSetup, uint256 _shares) public {
        _assumeCustomSetup(_customSetup);

        vm.assume(_shares > 0);

        assertEq(
            xSilo.previewRedeem(_shares),
            xSilo.getAmountByVestingDuration(_shares, 0),
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

        address user = makeAddr("user");

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

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeem_all
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_redeem_all(uint256 _silos) public {
        vm.assume(_silos > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        address user = makeAddr("user");

        _convert(user, _silos);

        uint256 siloPreview = xSilo.getAmountByVestingDuration(xSilo.balanceOf(user), 0);
        vm.assume(siloPreview != 0);

        vm.startPrank(user);

        uint256 gotSilos = xSilo.redeem(xSilo.balanceOf(user), user, user);

        assertEq(
            siloPreview,
            gotSilos,
            "redeem give us same result as vesting with 0 duration"
        );

        assertEq(asset.balanceOf(user), gotSilos, "user got exact amount of tokens");

        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeem_usesDuration0
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_redeem_usesDuration0(
        uint256 _silos, uint256 _xSiloToRedeem
    ) public {
//        (uint256 _silos, uint256 _xSiloToRedeem) = (9133, 4696);

        vm.assume(_silos > 0);
        vm.assume(_xSiloToRedeem > 0);
        vm.assume(_silos < type(uint256).max / 100); // to not cause overflow on calculation

        address user = makeAddr("user");

        _convert(user, _silos);
        vm.assume(_xSiloToRedeem <= xSilo.balanceOf(user));

        uint256 siloPreview = xSilo.getAmountByVestingDuration(_xSiloToRedeem, 0);
        vm.assume(siloPreview != 0);

        vm.startPrank(user);

        uint256 gotSilos = xSilo.redeem(_xSiloToRedeem, user, user);

        assertEq(
            siloPreview,
            gotSilos,
            "redeem give us same result as vesting with 0 duration"
        );

        assertEq(asset.balanceOf(user), gotSilos, "user got exact amount of tokens");

        vm.stopPrank();
    }

    struct TestFlow {
        uint64 amount;
        uint64 redeemDuration;
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_xSilo_flowShouldNotRevert
    */
    /// forge-config: x_silo.fuzz.runs = 1000
    function test_xSilo_flowShouldNotRevert(
        TestFlow[] memory _data,
        uint32 _emissionPerSecond,
        uint32 _streamDistribution
    ) public {
        vm.assume(_data.length > 0);
        vm.assume(_data.length <= 50);

        for (uint i = 0; i < _data.length; i++) {
            emit log_named_uint("--------- depositing", i);

            address user = _userAddr(i);
            uint256 amount = _data[i].amount;
            vm.assume(amount > 1e3); // to prevent ratio issue on stream rewards

            _convert(user, amount);
            vm.warp(block.timestamp + 1 minutes);
        }

        _setupStream(_emissionPerSecond, block.timestamp + _streamDistribution);
        vm.warp(block.timestamp + 1 hours);

        uint256 allFinishAt = block.timestamp + _streamDistribution;

        for (uint i = 0; i < _data.length; i++) {
            emit log_named_uint("--------- redeemSilo", i);

            address user = _userAddr(i);
            uint256 amount = xSilo.balanceOf(user) * 10 / 100;
            if (amount == 0) continue;

            uint256 redeemDuration = Math.min(_data[i].redeemDuration, xSilo.maxRedeemDuration());
            allFinishAt = Math.max(block.timestamp + redeemDuration, allFinishAt);

            vm.prank(user);
            xSilo.redeemSilo(amount, redeemDuration);
            vm.warp(block.timestamp + 30 minutes);
        }

        vm.warp(allFinishAt + 1);

        address admin = makeAddr("admin");

        for (uint i = 0; i < _data.length; i++) {
            emit log_named_uint("--------- exiting", i);

            address user = _userAddr(i);
            uint256 amount = xSilo.balanceOf(user);

            if (xSilo.getUserRedeemsLength(user) != 0) {
                vm.prank(user);
                xSilo.finalizeRedeem(0);
                vm.warp(block.timestamp + 30 minutes);
            }

            if (xSilo.maxWithdraw(user) != 0) {
                vm.prank(user);
                xSilo.redeemSilo(amount, 0);
                vm.warp(block.timestamp + 30 minutes);
            } else if (amount != 0) {
                vm.prank(user);
                xSilo.transfer(admin, amount);
            } else {
                stream.claimRewards();
            }
        }

        assertLe(stream.pendingRewards(), 0, "there should be no pending rewards");
        assertLe(asset.balanceOf(address(stream)), 0, "stream has no balance (dust acceptable)");
        assertLe(xSilo.balanceOf(admin), 0, "leftover that users can't withdraw");
    }

    function _userAddr(uint256 _i) internal returns (address addr) {
        addr = makeAddr(string.concat("user#", string(abi.encodePacked(_i + 48))));
    }

    function _setupStream(uint256 _emissionPerSecond, uint256 _distribution) internal {
        stream.setEmissions(_emissionPerSecond, block.timestamp + _distribution);
        asset.mint(address(stream), stream.fundingGap());
    }

    function _convert(address _user, uint256 _amount) internal returns (uint256 shares){
        vm.startPrank(_user);

        asset.mint(_user, _amount);
        asset.approve(address(xSilo), _amount);
        shares = xSilo.deposit(_amount, _user);

        assertGt(shares, 0, "[_convert] shares received");

        vm.stopPrank();
    }

    function _defaultSetupVerification() internal view {
        // all tests are done for this setup:

        assertEq(xSilo.minRedeemRatio(), 0.5e2, "expected initial setup for minRedeemRatio");
        assertEq(xSilo.maxRedeemRatio(), 1e2, "expected initial setup for maxRedeemRatio");
        assertEq(xSilo.minRedeemDuration(), 0, "expected initial setup for minRedeemDuration");
        assertEq(xSilo.maxRedeemDuration(), 6 * 30 days, "expected initial setup for maxRedeemDuration");
    }

    function _assumeCustomSetup(CustomSetup memory _customSetup) internal {
        _customSetup.maxRedeemRatio = uint64(bound(_customSetup.maxRedeemRatio, 0, _PRECISION));
        _customSetup.minRedeemRatio = uint64(bound(_customSetup.minRedeemRatio, 0, _customSetup.maxRedeemRatio));
        _customSetup.maxRedeemDuration = uint64(bound(_customSetup.maxRedeemDuration, 1, 365 days));
        _customSetup.minRedeemDuration = uint64(bound(_customSetup.minRedeemDuration, 0, _customSetup.maxRedeemDuration - 1));

        emit log_named_uint("minRedeemRatio", _customSetup.minRedeemRatio);
        emit log_named_uint("maxRedeemRatio", _customSetup.maxRedeemRatio);
        emit log_named_uint("minRedeemDuration", _customSetup.minRedeemDuration);
        emit log_named_uint("maxRedeemDuration", _customSetup.maxRedeemDuration);

        try xSilo.updateRedeemSettings({
            _minRedeemRatio: _customSetup.minRedeemRatio,
            _maxRedeemRatio: _customSetup.maxRedeemRatio,
            _minRedeemDuration: _customSetup.minRedeemDuration,
            _maxRedeemDuration: _customSetup.maxRedeemDuration
        }) {
            // OK
        } catch {
            vm.assume(false);
        }
    }
}
