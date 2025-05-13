// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {ERC4626Mock} from "openzeppelin5/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {Stream} from "../../../contracts/modules/Stream.sol";

/*
FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mc StreamTest
*/
contract StreamTest is Test {
    ERC20Mock token;
    Stream stream;
    ERC4626 beneficiary;

    function setUp() public {
        token = new ERC20Mock();
        beneficiary = new ERC4626Mock(address(token));
        stream = new Stream(address(this), address(beneficiary));

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
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_1perSecFlow
    */
    function test_1perSecFlow() public {

        stream.setEmissions(1, block.timestamp + 100);
        assertEq(stream.pendingRewards(), 0, "no pendingRewards when distribution did not start yet");
        assertEq(stream.fundingGap(), 100, "fundingGap is 100% from begin");

        vm.warp(block.timestamp + 1);
        assertEq(stream.pendingRewards(), 1, "pendingRewards for 1 sec");

        vm.warp(block.timestamp + 49);
        assertEq(stream.pendingRewards(), 50, "pendingRewards for 50 sec");

        token.mint(address(stream), 50);
        assertEq(stream.claimRewards(), 50, "claimRewards");
        assertEq(token.balanceOf(address(beneficiary)), 50, "beneficiary got rewards");

        // much over the distribution time
        vm.warp(block.timestamp + 3 days);

        assertEq(stream.pendingRewards(), 50, "pendingRewards shows what's left");
        assertEq(stream.fundingGap(), 50, "fundingGap returns what's missing");

        token.mint(address(stream), 50);
        assertEq(stream.claimRewards(), 50, "claimRewards");
        assertEq(token.balanceOf(address(beneficiary)), 100, "beneficiary got 100% rewards");
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
    function test_pendingRewardsMustMatchClaim_fuzz(uint32 _emissionPerSecond, uint64 _distributionEnd, uint64 _warp) public {
        vm.assume(_distributionEnd > 0);

        stream.setEmissions(_emissionPerSecond, block.timestamp + _distributionEnd);

        token.mint(address(stream), stream.fundingGap());

        vm.warp(block.timestamp + _warp);
        assertEq(stream.pendingRewards(), stream.claimRewards(), "pendingRewards must match claim");
    }

    function _assert_zeros() private {
        assertEq(stream.fundingGap(), 0, "no gap when no distribution");
        assertEq(stream.pendingRewards(), 0, "no pendingRewards when no distribution");
        assertEq(stream.claimRewards(), 0, "no claimRewards when no distribution");
    }
}
