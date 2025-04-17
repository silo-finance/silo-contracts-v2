// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {EggsToSonicAdapter, IEggsLike} from "silo-oracles/contracts/custom/EggsToSonicAdapter.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract EggsToSonicAdapterTest
*/
contract EggsToSonicAdapterTest is TokensGenerator {
    uint256 constant TEST_BLOCK = 10717305;
    IEggsLike constant EGGS = IEggsLike(0xf26Ff70573ddc8a90Bd7865AF8d7d70B8Ff019bC);
    IERC20Metadata constant WS = IERC20Metadata(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    constructor() TokensGenerator(BlockChain.SONIC) {
        initFork(TEST_BLOCK);
    }

    function test_EggsToSonicAdapter_constructor() public {
        EggsToSonicAdapter adapter = new EggsToSonicAdapter(EGGS);
        assertEq(address(adapter.EGGS()), address(EGGS), "Eggs is set in constructor");

        assertEq(adapter.SAMPLE_AMOUNT(), 10**18, "Sample amount is correct");
        assertEq(adapter.decimals(), 18, "adapter decimals are 18");

        assertEq(adapter.RATE_DIVIDER(), 1000, "rate divider is correct");
        assertEq(adapter.RATE_MULTIPLIER(), 989, "rate multiplier is correct to get 98.9%");
        assertEq(1000 * adapter.RATE_MULTIPLIER() / adapter.RATE_DIVIDER(), 989, "sanity check of 98.9%");
    }

    function test_EggsToSonicAdapter_constructor_reverts() public {
        vm.expectRevert();
        new EggsToSonicAdapter(IEggsLike(address(WS)));

        vm.expectRevert(EggsToSonicAdapter.InvalidEggsAddress.selector);
        new EggsToSonicAdapter(IEggsLike(address(0)));

        vm.expectRevert();
        new EggsToSonicAdapter(IEggsLike(address(this)));

        vm.expectRevert();
        new EggsToSonicAdapter(IEggsLike(address(111112)));
    }

    function test_EggsToSonicAdapter_latestRoundData_compareToOriginalRate() public {
        AggregatorV3Interface aggregator = AggregatorV3Interface(new EggsToSonicAdapter(EGGS));
        int256 originalRate = int256(EGGS.EGGStoSONIC(1 ether));
        int256 originalRateScaledDown = originalRate * 989 / 1000;

        assertTrue(originalRateScaledDown < originalRate, "scaled down rate is less as expected");
        assertTrue(originalRateScaledDown > originalRate * 98 / 100, "but scaled down rate is >98%");

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = aggregator.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, originalRateScaledDown);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_EggsToSonicAdapter_latestRoundData_answerSanity() public {
        AggregatorV3Interface aggregator = AggregatorV3Interface(new EggsToSonicAdapter(EGGS));

        (, int256 answer, , , ) = aggregator.latestRoundData();

        assertEq(IERC20Metadata(address(EGGS)).decimals(), 18, "EGGS decimals are 18");
        assertEq(WS.decimals(), 18, "wS decimals are 18");

        // $0.63 sonic price per block (external source)
        // $0.0007146 eggs price per block (external source)
        // expected price is eggs/$ / S/$ = 1.1342 * 10**15
        // price from adapter is 1123812498083768
        // which is close with 0.991 relative precision, less than 1% difference with calculated value.

        int256 expectedAnswer = 1134 * 10**12;

        assertEq(answer, 1123812498083768);

        assertTrue(
            answer > expectedAnswer * 99/100 && answer < expectedAnswer,
            "answer should be close to precalculated with 1% error"
        );
    }
}
