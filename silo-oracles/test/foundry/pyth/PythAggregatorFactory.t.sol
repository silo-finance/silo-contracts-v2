// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {PythAggregatorFactory} from "silo-oracles/contracts/pyth/PythAggregatorFactory.sol";
import {IPythAggregatorFactory} from "silo-oracles/contracts/interfaces/IPythAggregatorFactory.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract PythAggregatorFactoryTest
*/
contract PythAggregatorFactoryTest is TokensGenerator {
    uint256 constant TEST_BLOCK = 4022009;
    address constant PYTH = 0x2880aB155794e7179c9eE2e38200202908C17B43;
    bytes32 constant PYTH_S_USD_PRICE_ID = 0xf490b178d0c85683b7a0f2388b40af2e6f7c90cbe0f96b31f315f08d0e5a2d6d;
    bytes32 constant PYTH_ETH_USD_PRICE_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    event AggregatorDeployed(bytes32 indexed priceId, AggregatorV3Interface indexed aggregator);

    constructor() TokensGenerator(BlockChain.SONIC) {
        initFork(TEST_BLOCK);
    }

    function test_SonicFork() public view {
        _testExpectedBlockNumber("Should fork to Sonic");
    }

    function test_PythAggregatorFactory_constructor() public {
        PythAggregatorFactory factory = new PythAggregatorFactory(PYTH);

        assertEq(factory.pyth(), PYTH, "Pyth set correctly");
    }

    function test_PythAggregatorFactory_deploy_correctness() public {
        PythAggregatorFactory factory = new PythAggregatorFactory(PYTH);
        AggregatorV3Interface ethAggregator = factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));

        (, int256 answer,, uint256 updatedAt,) = ethAggregator.latestRoundData();
        uint8 decimals = ethAggregator.decimals();

        assertEq(decimals, 8, "Decimals() of deployed ETH/USD aggregator works, equal to 8");
        assertEq(answer / int256(10 ** uint256(decimals)), 3345, "Price of ETH is correct with decimals");
        assertTrue(block.timestamp - updatedAt < 100, "Price of ETH is recently updated, less than 100s ago");

        AggregatorV3Interface sAggregator = factory.deploy(PYTH_S_USD_PRICE_ID, bytes32(0));
        (, answer,,,) = sAggregator.latestRoundData();
        decimals = sAggregator.decimals();

        assertEq(decimals, 8, "Decimals are 8 for s aggregator too");
        assertEq(answer, 80640807, "Price of s is correct with decimals, ~0.8$");
    }

    function test_PythAggregatorFactory_deploy_revertsOnDuplicate() public {
        PythAggregatorFactory factory = new PythAggregatorFactory(PYTH);
        factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));

        vm.expectRevert(IPythAggregatorFactory.AggregatorAlreadyExists.selector);
        factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));
    }

    function test_PythAggregatorFactory_deploy_emitsEvent() public {
        PythAggregatorFactory factory = new PythAggregatorFactory(PYTH);
        vm.expectEmit(true, false, false, false);
        emit AggregatorDeployed(PYTH_ETH_USD_PRICE_ID, AggregatorV3Interface(address(0)));

        factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));
    }

    function test_PythAggregatorFactory_aggregators() public {
        PythAggregatorFactory factory = new PythAggregatorFactory(PYTH);
        assertEq(address(factory.aggregators(PYTH_ETH_USD_PRICE_ID)), address(0), "Aggregator is not created yet");

        AggregatorV3Interface ethAggregator = factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));
        assertEq(address(factory.aggregators(PYTH_ETH_USD_PRICE_ID)), address(ethAggregator), "Aggregator updated");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_PythAggregatorFactory_reorg -vv
    */
    function test_PythAggregatorFactory_reorg() public {
        PythAggregatorFactory factory = new PythAggregatorFactory(PYTH);

        address eoa1 = makeAddr("eoa1");
        address eoa2 = makeAddr("eoa2");

        uint256 snapshot = vm.snapshotState();

        vm.prank(eoa1);
        AggregatorV3Interface ethAggregator1 = factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));

        vm.revertToState(snapshot);

        vm.prank(eoa2);
        AggregatorV3Interface ethAggregator2 = factory.deploy(PYTH_ETH_USD_PRICE_ID, bytes32(0));

        assertNotEq(address(ethAggregator1), address(ethAggregator2), "ethAggregator1 == ethAggregator2");
    }
}
