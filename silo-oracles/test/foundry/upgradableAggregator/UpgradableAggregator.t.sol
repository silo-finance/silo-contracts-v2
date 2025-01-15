// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "../../../constants/Sonic.sol";

import {UpgradableAggregator} from "silo-oracles/contracts/upgradableAggregator/UpgradableAggregator.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";
import {MockAggregatorV3} from "silo-oracles/test/foundry/_common/MockAggregatorV3.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract UpgradableAggregatorTest
*/
contract UpgradableAggregatorTest is TokensGenerator {
    uint256 constant TEST_BLOCK = 4022009;
    AggregatorV3Interface underlyingFeed = AggregatorV3Interface(PYTH_AGGREGATOR_ETH_USD);
    address mockMultisig = address(123);

    event UnderlyingFeedUpdated(AggregatorV3Interface indexed newUnderlyingFeed);

    constructor() TokensGenerator(BlockChain.SONIC) {
        initFork(TEST_BLOCK);
    }

    function test_SonicFork() public view {
        _testExpectedBlockNumber("Should fork to Sonic");
    }

    function test_UpgradableAggregator_constructor() public {
        UpgradableAggregator aggregator = new UpgradableAggregator(mockMultisig, underlyingFeed);

        assertEq(aggregator.decimals(), underlyingFeed.decimals(), "Decimals must be equal to initial aggregator");
        assertEq(aggregator.decimals(), 8, "Decimals must be equal to 8");
        assertEq(aggregator.decimals(), aggregator.AGGREGATOR_DECIMALS());
        assertEq(address(aggregator.underlyingFeed()), address(underlyingFeed), "Underlying aggregator is set");
        assertEq(aggregator.owner(), mockMultisig, "Owner is correct");
    }

    function test_UpgradableAggregator_decimals_areNotUpdated() public {
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), underlyingFeed);

        aggregator.changeUnderlyingFeed(new MockAggregatorV3(0, 0));
        assertEq(aggregator.decimals(), underlyingFeed.decimals(), "Decimals MUST NOT be updated");
        assertEq(aggregator.decimals(), aggregator.AGGREGATOR_DECIMALS());

        aggregator.changeUnderlyingFeed(new MockAggregatorV3(0, 0));
        assertEq(aggregator.decimals(), underlyingFeed.decimals(), "Decimals MUST NOT be updated");
    }

    function test_UpgradableAggregator_description() public {
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), underlyingFeed);
        assertEq(aggregator.description(), underlyingFeed.description(), "Description must be forwarded");

        aggregator.changeUnderlyingFeed(new MockAggregatorV3(0, 0));
        assertEq(aggregator.description(), "Mocked aggregator for QA only", "Description must be updated");
    }

    function test_UpgradableAggregator_version() public {
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), underlyingFeed);
        assertEq(aggregator.version(), underlyingFeed.version(), "Version must be forwarded");

        MockAggregatorV3 mockedAggregator = new MockAggregatorV3(0, 0);
        aggregator.changeUnderlyingFeed(mockedAggregator);
        assertEq(aggregator.version(), mockedAggregator.version(), "Version must be updated");
    }

    function test_UpgradableAggregator_changeUnderlyingFeed_worksAndEmitsEvent() public {
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), underlyingFeed);

        MockAggregatorV3 mockedAggregator = new MockAggregatorV3(0, 0);
        vm.expectEmit(true, false, false, false);
        emit UnderlyingFeedUpdated(mockedAggregator);
        aggregator.changeUnderlyingFeed(mockedAggregator);
        assertEq(address(aggregator.underlyingFeed()), address(mockedAggregator), "Underlying feed is updated");
    }

    function test_UpgradableAggregator_changeUnderlyingFeed_isProtected() public {
        address owner = address(12345);
        UpgradableAggregator aggregator = new UpgradableAggregator(owner, underlyingFeed);
        MockAggregatorV3 mockedAggregator = new MockAggregatorV3(0, 0);

        vm.expectRevert();
        aggregator.changeUnderlyingFeed(mockedAggregator);

        vm.prank(owner);
        aggregator.changeUnderlyingFeed(mockedAggregator);
        assertEq(address(aggregator.underlyingFeed()), address(mockedAggregator), "Owner can update the feed");
    }

    function test_UpgradableAggregator_latestRoundData_forwardsCall() public {
        int256 expectedPrice = 12345;
        uint8 expectedDecimals = 4;

        MockAggregatorV3 mockedAggregator = new MockAggregatorV3(expectedPrice, expectedDecimals);
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), mockedAggregator);
        
        (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) = aggregator.latestRoundData();

        (
            uint80 originalRoundId,
            int256 originalAnswer,
            uint256 originalStartedAt,
            uint256 originalUpdatedAt,
            uint80 originalAnsweredInRound
        ) =  mockedAggregator.latestRoundData();

        assertEq(roundId, originalRoundId, "Forwards roundId");
        assertEq(answer, originalAnswer, "Forwards answer");
        assertEq(startedAt, originalStartedAt, "Forwards startedAt");
        assertEq(updatedAt, originalUpdatedAt, "Forwards updatedAt");
        assertEq(answeredInRound, originalAnsweredInRound, "Forwards answeredInRound");

        aggregator.changeUnderlyingFeed(underlyingFeed);
        (roundId, answer, startedAt, updatedAt, answeredInRound) = aggregator.latestRoundData();
        (originalRoundId, originalAnswer, originalStartedAt, originalUpdatedAt, originalAnsweredInRound) =  underlyingFeed.latestRoundData();

        assertEq(roundId, originalRoundId, "Forwards roundId after feed update");
        assertEq(startedAt, originalStartedAt, "Forwards startedAt after feed update");
        assertEq(updatedAt, originalUpdatedAt, "Forwards updatedAt after feed update");
        assertEq(answeredInRound, originalAnsweredInRound, "Forwards answeredInRound after feed update");

        assertEq(underlyingFeed.decimals() - mockedAggregator.decimals(), 4, "Decimals of underlying feed increased by 4: 4->8");
        assertEq(answer, originalAnswer / 10**4, "Normalizes answer after feed update. Original answer is divided by 10**4");
        assertEq(aggregator.decimals(), mockedAggregator.decimals(), "Decimals did not change");
    }

    function test_UpgradableAggregator_latestRoundData_decimalsNormalizationScenarios() public {
        uint8 initialDecimals = 18;
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), new MockAggregatorV3(0, initialDecimals));

        uint8 newUnderlyingDecimals = 17;
        int256 newUnderlyingPrice = 10 ** 17; 
        aggregator.changeUnderlyingFeed(new MockAggregatorV3(newUnderlyingPrice, newUnderlyingDecimals));
        (, int256 answer,,,) = aggregator.latestRoundData();
        assertEq(answer, 10**18, "Price is normalized from 17 decimals to 18 decimals");
        assertEq(aggregator.decimals(), 18, "Decimals are 18");

        newUnderlyingDecimals = 19;
        newUnderlyingPrice = 10 ** 19; 
        aggregator.changeUnderlyingFeed(new MockAggregatorV3(newUnderlyingPrice, newUnderlyingDecimals));
        (, answer,,,) = aggregator.latestRoundData();
        assertEq(answer, 10**18, "Price is normalized from 19 decimals to 18 decimals");
        assertEq(aggregator.decimals(), 18, "Decimals are still 18");

        newUnderlyingDecimals = 18;
        newUnderlyingPrice = 10 ** 18; 
        aggregator.changeUnderlyingFeed(new MockAggregatorV3(newUnderlyingPrice, newUnderlyingDecimals));
        (, answer,,,) = aggregator.latestRoundData();
        assertEq(answer, 10**18, "Price is normalized from 18 decimals to 18 decimals, nothing changed");

        newUnderlyingDecimals = 0;
        newUnderlyingPrice = 15; 
        aggregator.changeUnderlyingFeed(new MockAggregatorV3(newUnderlyingPrice, newUnderlyingDecimals));
        (, answer,,,) = aggregator.latestRoundData();
        assertEq(answer, newUnderlyingPrice * 10**18, "Price is normalized from 0 decimals to 18 decimals");
    }

    function test_UpgradableAggregator_getRoundData_forwardsCall() public {
        int256 expectedPrice = 12345;
        uint8 expectedDecimals = 4;

        MockAggregatorV3 mockedAggregator = new MockAggregatorV3(expectedPrice, expectedDecimals);
        UpgradableAggregator aggregator = new UpgradableAggregator(address(this), mockedAggregator);
        
        (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) = aggregator.getRoundData(0);

        (
            uint80 originalRoundId,
            int256 originalAnswer,
            uint256 originalStartedAt,
            uint256 originalUpdatedAt,
            uint80 originalAnsweredInRound
        ) =  mockedAggregator.getRoundData(0);

        assertEq(roundId, originalRoundId, "Forwards roundId");
        assertEq(answer, originalAnswer, "Forwards answer");
        assertEq(startedAt, originalStartedAt, "Forwards startedAt");
        assertEq(updatedAt, originalUpdatedAt, "Forwards updatedAt");
        assertEq(answeredInRound, originalAnsweredInRound, "Forwards answeredInRound");

        aggregator.changeUnderlyingFeed(underlyingFeed);
        (roundId, answer, startedAt, updatedAt, answeredInRound) = aggregator.getRoundData(0);
        (originalRoundId, originalAnswer, originalStartedAt, originalUpdatedAt, originalAnsweredInRound) =  underlyingFeed.getRoundData(0);

        assertEq(roundId, originalRoundId, "Forwards roundId after feed update");
        assertEq(startedAt, originalStartedAt, "Forwards startedAt after feed update");
        assertEq(updatedAt, originalUpdatedAt, "Forwards updatedAt after feed update");
        assertEq(answeredInRound, originalAnsweredInRound, "Forwards answeredInRound after feed update");

        assertEq(underlyingFeed.decimals() - mockedAggregator.decimals(), 4, "Decimals of underlying feed increased by 4: 4->8");
        assertEq(answer, originalAnswer / 10**4, "Normalizes answer after feed update. Original answer is divided by 10**4");
        assertEq(aggregator.decimals(), mockedAggregator.decimals(), "Decimals did not change");
    }    
}
