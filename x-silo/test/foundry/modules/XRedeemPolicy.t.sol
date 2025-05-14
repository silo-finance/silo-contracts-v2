// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {XSilo, XRedeemPolicy, Stream, ERC20} from "../../../contracts/XSilo.sol";
import {XSiloAndStreamDeploy} from "x-silo/deploy/XSiloAndStreamDeploy.s.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

/*
FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mc XRedeemPolicyTest
*/
contract XRedeemPolicyTest is Test {
    Stream stream;
    XSilo policy;
    ERC20Mock asset;

    event UpdateRedeemSettings(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration);
    event StartRedeem(address indexed _userAddress, uint256 currentSiloAmount, uint256 xSiloToBurn, uint256 siloAmountAfterVesting, uint256 duration);
    event FinalizeRedeem(address indexed _userAddress, uint256 siloToRedeem, uint256 xSiloToBurn);
    event CancelRedeem(address indexed _userAddress, uint256 xSiloToTransfer, uint256 xSiloToBurn);

    function setUp() public {
        AddrLib.init();

        asset = new ERC20Mock();

        AddrLib.setAddress(AddrKey.SILO_TOKEN_V2, address(asset));
        AddrLib.setAddress(AddrKey.DAO, address(this));

        XSiloAndStreamDeploy deploy = new XSiloAndStreamDeploy();
        deploy.disableDeploymentsSync();
        (policy, stream) = deploy.run();

        // TODO copy this file and create tests for randome setup?
        // all tests are done for this setup:

        assertEq(policy.minRedeemRatio(), 0.5e2, "expected initial setup for minRedeemRatio");
        assertEq(policy.maxRedeemRatio(), 1e2, "expected initial setup for maxRedeemRatio");
        assertEq(policy.minRedeemDuration(), 0, "expected initial setup for minRedeemDuration");
        assertEq(policy.maxRedeemDuration(), 6 * 30 days, "expected initial setup for maxRedeemDuration");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getXAmountByVestingDuration_whenZeroDuration_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_getXAmountByVestingDuration_whenZeroDuration_fuzz(uint256 _amount) public view {
        assertEq(
            policy.getXAmountByVestingDuration(_amount, 0),
            _amount / 2,
            "any amount for 0 duration returns 1/2"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getXAmountByVestingDuration_neverReverts_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_getXAmountByVestingDuration_neverReverts_fuzz(uint256 _amount, uint256 _duration) public view {
        policy.getXAmountByVestingDuration(_amount, _duration);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getAmountInByVestingDuration_zeroDuration_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_getAmountInByVestingDuration_zeroDuration_fuzz(uint256 _xSiloAfterVesting) public view {
        vm.assume(_xSiloAfterVesting <= type(uint128).max);

        assertEq(
            policy.getAmountInByVestingDuration(_xSiloAfterVesting, 0),
            _xSiloAfterVesting * 2,
            "any amount for 0 returns +50%"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getAmountInByVestingDuration_neverReverts_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_getAmountInByVestingDuration_neverReverts_fuzz(uint256 _xSiloAfterVesting, uint256 _duration)
        public
        view
    {
        vm.assume(_xSiloAfterVesting <= type(uint128).max);

        policy.getAmountInByVestingDuration(_xSiloAfterVesting, _duration);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getAmounts_crosscheck_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_getAmounts_crosscheck_fuzz(uint256 _xSiloAfterVesting, uint256 _duration) public view {
        vm.assume(_xSiloAfterVesting <= type(uint128).max);

        uint256 xSiloAmountIn = policy.getAmountInByVestingDuration(_xSiloAfterVesting, _duration);

        uint256 xSiloAfter = policy.getXAmountByVestingDuration(xSiloAmountIn, _duration);

        assertEq(xSiloAfter, _xSiloAfterVesting, "#1 crosscheck calculation");

        uint256 xAmountIn = policy.getAmountInByVestingDuration(xSiloAfter, _duration);

        assertEq(xAmountIn, xSiloAmountIn, "#2 crosscheck calculation");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getUserRedeemsBalance_whenAllZeros
    */
    function test_getUserRedeemsBalance_whenAllZeros() public view {
        assertEq(policy.getUserRedeemsBalance(address(1)), 0, "without queue no redeem balance");
        assertEq(policy.getUserRedeemsLength(address(1)), 0, "without items no queue");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_getUserRedeem_revertsOnInvalidIndex
    */
    function test_getUserRedeem_revertsOnInvalidIndex() public {
        vm.expectRevert(XRedeemPolicy.RedeemIndexDoesNotExist.selector);
        policy.getUserRedeem(address(1), 100);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_zeros
    */
    function test_redeemSilo_zeros() public {
        vm.expectRevert(XRedeemPolicy.ZeroAmount.selector);
        policy.redeemSilo(0, 0);

        vm.expectRevert(XRedeemPolicy.NoSiloToRedeem.selector);
        policy.redeemSilo(1, 0);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_emits_StartRedeem_noRewards_1s
    */
    function test_redeemSilo_emits_StartRedeem_noRewards_1s() public {
        uint256 toRedeem = 0.5e18;
        uint256 duration = 1 seconds;

        _redeemSilo_emits_StartRedeem_noRewards_halfTime(toRedeem, duration, toRedeem / 2);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_emits_StartRedeem_noRewards_halfTime
    */
    function test_redeemSilo_emits_StartRedeem_noRewards_halfTime() public {
        uint256 toRedeem = 0.5e18;
        uint256 halfTime = policy.maxRedeemDuration() / 2;

        _redeemSilo_emits_StartRedeem_noRewards_halfTime(toRedeem, halfTime, toRedeem * 3 / 4);
    }

    function _redeemSilo_emits_StartRedeem_noRewards_halfTime(
        uint256 _toRedeem,
        uint256 _duration,
        uint256 _siloAmountAfterVesting
    )
        public
    {
        uint256 amount = 1e18;

        address user = makeAddr("user");
        _convert(user, amount);

        vm.expectEmit(address(policy));
        emit StartRedeem(user, _toRedeem, _toRedeem, _siloAmountAfterVesting, _duration);

        vm.prank(user);
        policy.redeemSilo(_toRedeem, _duration);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_immediate_noStream
    */
    function test_redeemSilo_immediate_noStream() public {
        address user = makeAddr("user");
        vm.startPrank(user);

        asset.mint(user, 100);
        asset.approve(address(policy), 100);

        policy.deposit(asset.balanceOf(user), user);
        policy.redeemSilo(policy.balanceOf(user), 0);

        assertEq(policy.totalSupply(), 0, "vault should be empty");
        assertEq(policy.balanceOf(user), 0, "no user balance");
        assertEq(asset.balanceOf(user), 50, "user got 50% on immediate redeem");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_deposit_ZeroShares
    */
    function test_deposit_ZeroShares() public {
        address user = makeAddr("user");
        _setupStream();

        vm.warp(block.timestamp + 1 minutes);

        vm.startPrank(user);

        asset.mint(user, 100);
        asset.approve(address(policy), 100);

        vm.expectRevert(XSilo.ZeroShares.selector);
        policy.deposit(100, user);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_immediate_redeemTooMuch
    */
    function test_redeemSilo_immediate_redeemTooMuch(bool _withRewards, uint32 _warp) public {
        address user = makeAddr("user");

        vm.warp(block.timestamp + 1 minutes);

        uint256 shares = _convert(user, 100);

        if (_withRewards) _setupStream();
        if (_warp != 0) vm.warp(block.timestamp + _warp);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, shares, shares + 1));
        vm.prank(user);
        policy.redeemSilo(shares + 1, 0);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_immediate_noRewards_withStream_NoWarp_fuzz
    */
    function test_redeemSilo_immediate_noRewards_withStream_NoWarp_fuzz(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < 2 ** 128);

        address user = makeAddr("user");

        _convert(user, _amount);

        _setupStream();

        _ensure_redeemSilo_immediate_doesNotGiveRewards(user, _amount);

        assertEq(policy.totalSupply(), 0, "vault should be empty");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_immediate_noRewards_withStream_afterTime_fuzz
    */
    function test_redeemSilo_immediate_noRewards_withStream_afterTime_fuzz(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < 2 ** 128);

        _convert(makeAddr("first user"), 1e18);
        _setupStream();

        // some rewards in place
        vm.warp(block.timestamp + 1 days);

        address user = makeAddr("user");
        vm.assume(policy.previewDeposit(_amount) != 0);
        _convert(user, _amount);

        _ensure_redeemSilo_immediate_doesNotGiveRewards(user, _amount);
    }

    function _ensure_redeemSilo_immediate_doesNotGiveRewards(address _user, uint256 _amount) public {
        vm.startPrank(_user);

        uint256 shares = policy.balanceOf(_user);

        vm.assume(policy.getAmountByVestingDuration(shares, 0) != 0);

        policy.redeemSilo(shares, 0);
        vm.stopPrank();

        assertEq(policy.balanceOf(_user), 0, "no user balance");

        // in extreme cases we can get less that 50% because of precision error
        assertLe(
            asset.balanceOf(_user),
            _amount / 2,
            "user got up to 50% on immediate redeem (rewards not included because no time)"
        );
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_expectNoRewardsOnCancel_single
    */
    function test_redeemSilo_expectNoRewardsOnCancel_single() public {
        uint256 amount = 1e18;
        uint256 duration = 10 hours;

        _redeemSilo_expectNoRewardsOnCancel(amount, duration);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_redeemSilo_expectNoRewardsOnCancel_fuzz
    */
    function test_redeemSilo_expectNoRewardsOnCancel_fuzz(uint256 _amount, uint256 _duration) public {
        _redeemSilo_expectNoRewardsOnCancel(_amount, _duration);
    }

    function _redeemSilo_expectNoRewardsOnCancel(uint256 _amount, uint256 _duration) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < 2 ** 128);
        vm.assume(_duration > 0);
        vm.assume(_duration <= policy.maxRedeemDuration());

        address user = makeAddr("user");

        _convert(user, _amount);
        _setupStream(); // 0.01/s for 1 day

        vm.startPrank(user);

        vm.warp(block.timestamp + 1 hours);
        vm.assume(policy.previewDeposit(_amount) != 0);

        uint256 sharesBefore = policy.balanceOf(user);
        uint256 siloAmountBefore = policy.convertToAssets(sharesBefore);

        policy.redeemSilo(sharesBefore, _duration);
        vm.warp(block.timestamp + 1 days);

        uint256 expectedShares = policy.convertToShares(siloAmountBefore);

        vm.expectEmit(address(policy));
        emit CancelRedeem(user, expectedShares, sharesBefore - expectedShares);

        policy.cancelRedeem(0);

        vm.stopPrank();

        assertLt(expectedShares, sharesBefore, "cancel will reduce shares");
        assertEq(policy.balanceOf(user), expectedShares, "expectedShares");
        assertEq(asset.balanceOf(user), 0, "user did not get any Silo");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_settings_zero
    */
    function test_settings_zero() public {
        policy.updateRedeemSettings(0, 0, 0, 1);

        address user = makeAddr("user");

        _convert(user, 1e18);

        vm.startPrank(user);

        uint256 siloAmountAfterVesting = policy.getAmountByVestingDuration(1e18, 0);

        assertEq(siloAmountAfterVesting, 0, "siloAmountAfterVesting iz zero because min ratio is 0");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_updateRedeemSettings_onlyOwner
    */
    function test_updateRedeemSettings_onlyOwner() public {
        address someAddress = makeAddr("someAddress");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, someAddress));
        vm.prank(someAddress);
        policy.updateRedeemSettings(0, 0, 0, 0);
    }

    // TODO provide rewards and make sure we can claim all

    function _setupStream() public returns (uint256 emissionPerSecond) {
        emissionPerSecond = 0.01e18;

        stream.setEmissions(emissionPerSecond, 1 days);
        asset.mint(address(stream), stream.fundingGap());
    }

    function _convert(address _user, uint256 _amount) public returns (uint256 shares){
        vm.startPrank(_user);

        asset.mint(_user, _amount);
        asset.approve(address(policy), _amount);
        shares = policy.deposit(_amount, _user);

        assertGt(shares, 0, "[_convert] shares received");

        vm.stopPrank();
    }
}
