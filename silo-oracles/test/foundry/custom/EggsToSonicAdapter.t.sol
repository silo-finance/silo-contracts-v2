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
    uint256 constant TEST_BLOCK = 9823015;
    IEggsLike constant EGGS = IEggsLike(0xf26Ff70573ddc8a90Bd7865AF8d7d70B8Ff019bC);
    IERC20Metadata constant WS = IERC20Metadata(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    constructor() TokensGenerator(BlockChain.SONIC) {
        initFork(TEST_BLOCK);
    }

    function test_EggsToSonicAdapter_constructor() public {
        IEggsLike mockEggs = IEggsLike(address(1235));
        EggsToSonicAdapter adapter = new EggsToSonicAdapter(mockEggs);
        assertEq(address(adapter.EGGS()), address(mockEggs), "Eggs is set in constructor");
        assertEq(adapter.SAMPLE_AMOUNT(), 10**18, "Sample amount is correct");

        assertEq(adapter.RATE_DIVIDER(), 1000, "rate divider is correct");
        assertEq(adapter.RATE_MULTIPLIER(), 989, "rate multiplier is correct to get 98.9%");

        assertEq(1000 * adapter.RATE_MULTIPLIER() / adapter.RATE_DIVIDER(), 989, "sanity check of 98.9%");
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

        // $0.837582 sonic price per block (external source)
        // $0.0009628 eggs price per block (external source)
        // expected price is 98.9% of 0.0009628 * 10**18/0.837582 ~ 98.9% of 1.149 * 10 ** 15 ~ 
        // ~ 98.9% of 1149 * 10 ** 12 ~ 1136 * 10**12.
        // price from adapter is 1123480200437355
        // which is close with 0.9886 relative precision, less than 2% difference with calculated value.

        int256 expectedAnswer = 1136 * 10**12;

        assertEq(answer, 1123480200437355);

        assertTrue(
            answer > expectedAnswer * 98/100 && answer < expectedAnswer,
            "answer should be close to precalculated with 2% error"
        );
    }
}
