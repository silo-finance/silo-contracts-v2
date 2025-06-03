// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {ERC4626Mock} from "openzeppelin5/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {Stream} from "../../../contracts/modules/Stream.sol";
import {StreamDeploy} from "x-silo/deploy/StreamDeploy.s.sol";
import {XSiloContracts} from "x-silo/common/XSiloContracts.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {IStream} from "x-silo/contracts/interfaces/IStream.sol";

/*
FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mc StreamTest
*/
contract StreamTest is Test {
    ERC20Mock token;
    Stream stream;
    ERC4626 beneficiary;

    function setUp() public {
        AddrLib.init();

        token = new ERC20Mock();
        beneficiary = new ERC4626Mock(address(token));

        AddrLib.setAddress(XSiloContracts.X_SILO, address(beneficiary));
        AddrLib.setAddress(AddrKey.DAO, address(this));

        StreamDeploy deploy = new StreamDeploy();
        deploy.disableDeploymentsSync();
        stream = deploy.run();

        _assert_zeros();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_zeros
    */
    function test_zeros() public {
        vm.warp(block.timestamp + 300 days);

        _assert_zeros();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setEmissions_zero
    */
    function test_setEmissions_zero() public {
        stream.setEmissions(100, block.timestamp + 100);
        assertEq(stream.emissionPerSecond(), 100, "emissionPerSecond 100");
        assertEq(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp is current one #1");
        assertEq(stream.distributionEnd(), block.timestamp + 100, "distributionEnd is in future");

        vm.warp(block.timestamp + 10);

        stream.setEmissions(0, block.timestamp + 1 days);
        assertEq(stream.emissionPerSecond(), 0, "emissionPerSecond should be reset to 0");
        assertEq(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp is current one #2");
        assertEq(stream.distributionEnd(), block.timestamp, "distributionEnd is ignored and set to current");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_1perSecFlow
    */
    function test_1perSecFlow() public {
        stream.setEmissions(1, block.timestamp + 100);
        assertEq(stream.pendingRewards(), 0, "no pendingRewards when distribution did not start yet");
        assertEq(stream.fundingGap(), 100, "fundingGap is 100% from begin");

        vm.warp(block.timestamp + 1);
        token.mint(address(stream), 1);
        assertEq(stream.pendingRewards(), 1, "pendingRewards for 1 sec");

        vm.warp(block.timestamp + 49);
        token.mint(address(stream), 50);

        assertEq(stream.pendingRewards(), 50, "pendingRewards for 50 sec");
        assertEq(stream.claimRewards(), 50, "claimRewards");
        assertEq(token.balanceOf(address(beneficiary)), 50, "beneficiary got rewards");

        // much over the distribution time
        vm.warp(block.timestamp + 3 days);
        assertEq(stream.fundingGap(), 49, "fundingGap returns what's missing");

        token.mint(address(stream), stream.fundingGap());

        assertEq(stream.pendingRewards(), 50, "pendingRewards shows what's left");

        assertEq(stream.claimRewards(), 50, "claimRewards");
        assertEq(token.balanceOf(address(beneficiary)), 100, "beneficiary got 100% rewards");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_noBalance
    */
    function test_noBalance() public {
        stream.setEmissions(1, block.timestamp + 100);
        assertEq(stream.pendingRewards(), 0, "no pendingRewards when distribution did not start yet");
        assertEq(stream.fundingGap(), 100, "fundingGap is 100% from begin");

        vm.warp(block.timestamp + 10);
        assertEq(stream.pendingRewards(), 0, "pendingRewards 0 when no balance");
        assertEq(stream.claimRewards(), 0, "claimRewards 0 whe nno balance");

        vm.warp(block.timestamp + 10);
        token.mint(address(stream), 3);
        assertEq(token.balanceOf(stream.BENEFICIARY()), 0, "BENEFICIARY didn't receive any rewards yet");

        assertEq(stream.pendingRewards(), 3, "pendingRewards returns max possible value");
        assertEq(stream.claimRewards(), 3, "claimRewards returns max possible value");
        assertEq(token.balanceOf(stream.BENEFICIARY()), 3, "BENEFICIARY got tokens");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_pendingRewardsMustMatchClaim_warpLoop_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_pendingRewardsMustMatchClaim_warpLoop_fuzz(uint32 _emissionPerSecond, uint64 _distributionEnd) public {
        vm.assume(_distributionEnd > 0);

        stream.setEmissions(_emissionPerSecond, block.timestamp + _distributionEnd);

        token.mint(address(stream), stream.fundingGap());

        assertEq(stream.pendingRewards(), stream.claimRewards(), "#1 pendingRewards must match claim");

        for (uint i = block.timestamp + 1; i < 3 minutes; i += 3) {
            vm.warp(i);
            assertEq(stream.pendingRewards(), stream.claimRewards(), "#2 pendingRewards must match claim");
        }
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_pendingRewardsMustMatchClaim_warpLoop_withFounding_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_pendingRewardsMustMatchClaim_warpLoop_withFounding_fuzz(uint32 _emissionPerSecond, uint64 _distributionEnd) public {
        vm.assume(_distributionEnd > 0);

        stream.setEmissions(_emissionPerSecond, block.timestamp + _distributionEnd);

        token.mint(address(stream), stream.fundingGap());

        assertEq(stream.pendingRewards(), stream.claimRewards(), "#1 pendingRewards must match claim");

        for (uint i = block.timestamp + 1; i < 3 minutes; i += 3) {
            vm.warp(i);
            token.mint(address(stream), 1e18);
            assertEq(stream.pendingRewards(), stream.claimRewards(), "#2 pendingRewards must match claim");
        }
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_pendingRewardsMustMatchClaim_warpLoop_withFounding_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_pendingRewardsMustMatchClaim_warpLoop_noFounding_fuzz(uint32 _emissionPerSecond, uint64 _distributionEnd) public {
        vm.assume(_distributionEnd > 0);

        stream.setEmissions(_emissionPerSecond, block.timestamp + _distributionEnd);

        assertEq(stream.pendingRewards(), stream.claimRewards(), "#1 pendingRewards must match claim");

        for (uint i = block.timestamp + 1; i < 3 minutes; i += 3) {
            vm.warp(i);
            assertEq(stream.pendingRewards(), stream.claimRewards(), "#2 pendingRewards must match claim");
        }
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_pendingRewardsMustMatchClaim_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_pendingRewardsMustMatchClaim_fuzz(uint32 _emissionPerSecond, uint64 _distributionEnd, uint64 _warp)
        public
    {
        vm.assume(_distributionEnd > 0);
        vm.assume(block.timestamp + _distributionEnd + _warp < 2 ** 64 - 1);

        stream.setEmissions(_emissionPerSecond, block.timestamp + _distributionEnd);

        token.mint(address(stream), stream.fundingGap());

        vm.warp(block.timestamp + _warp);
        assertEq(stream.pendingRewards(), stream.claimRewards(), "pendingRewards must match claim");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_claimRewards_neverReverts_fuzz
    */
    /// forge-config: x_silo.fuzz.runs = 10000
    function test_claimRewards_neverReverts_fuzz(
        uint32 _emissionPerSecond,
        uint64 _distributionEnd
    ) public {
        vm.assume(_distributionEnd > 0);
        vm.assume(block.timestamp + _distributionEnd < 2 ** 64 - 10); // -10 to have space for warp 1s few times

        _pendingClaimAndWarp(1);

        stream.setEmissions(_emissionPerSecond, block.timestamp + _distributionEnd);

        _pendingClaimAndWarp(1);

        token.mint(address(stream), 1);

        _pendingClaimAndWarp(1);

        token.mint(address(stream), stream.fundingGap());

        _pendingClaimAndWarp(_distributionEnd);

        _pendingClaimAndWarp(1);
    }

    // helper method for test_claimRewards_neverReverts_fuzz
    function _pendingClaimAndWarp(uint256 _warp) internal {
        stream.pendingRewards();
        stream.claimRewards();

        vm.warp(block.timestamp + _warp);

        stream.pendingRewards();
        stream.claimRewards();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_lastUpdateTimestamp_update_whenRewards
    */
    function test_lastUpdateTimestamp_update_whenRewards() public {
        stream.setEmissions(1e18, block.timestamp + 1 days);

        token.mint(address(stream), stream.fundingGap());

        vm.warp(block.timestamp + 1);

        assertGt(stream.pendingRewards(), 0, "expect rewards");
        assertLt(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp is in past before update");

        stream.claimRewards();

        assertEq(stream.pendingRewards(), 0, "expect NO rewards");
        assertEq(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp is updated");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_lastUpdateTimestamp_update_noBalance
    */
    function test_lastUpdateTimestamp_update_noBalance() public {
        stream.setEmissions(1e18, block.timestamp + 1 days);

        vm.warp(block.timestamp + 1);

        assertEq(stream.pendingRewards(), 0, "expect NO rewards because no balance");
        assertLt(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp is in past before update");

        stream.claimRewards();

        assertEq(stream.pendingRewards(), 0, "expect NO rewards");
        assertEq(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp is updated");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setEmissions_onlyOwner
    */
    function test_setEmissions_onlyOwner() public {
        address someAddress = makeAddr("someAddress");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, someAddress));
        vm.prank(someAddress);
        stream.setEmissions(1e18, block.timestamp + 1 days);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_emergencyWithdraw_onlyOwner
    */
    function test_emergencyWithdraw_onlyOwner() public {
        address someAddress = makeAddr("someAddress");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, someAddress));
        vm.prank(someAddress);
        stream.emergencyWithdraw();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_emergencyWithdraw_NoBalance
    */
    function test_emergencyWithdraw_NoBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IStream.NoBalance.selector));
        stream.emergencyWithdraw();
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_emergencyWithdraw_success
    */
    function test_emergencyWithdraw_success() public {
        uint256 amount = 1e18;

        token.mint(address(stream), amount);

        assertEq(token.balanceOf(address(stream)), amount, "stream should have balance");
        assertEq(token.balanceOf(address(this)), 0, "owner should have no balance");

        stream.emergencyWithdraw();

        assertEq(token.balanceOf(address(stream)), 0, "stream should have no balance");
        assertEq(token.balanceOf(address(this)), amount, "owner should have balance");
    }

    function _assert_zeros() private {
        assertEq(stream.fundingGap(), 0, "no gap when no distribution");
        assertEq(stream.pendingRewards(), 0, "no pendingRewards when no distribution");
        assertEq(stream.claimRewards(), 0, "no claimRewards when no distribution");
    }
}
