// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {WrappedMetaVaultOracleAdapterDeploy} from "silo-oracles/deploy/WrappedMetaVaultOracleAdapterDeploy.sol";
import {
    WrappedMetaVaultOracleAdapter,
    IWrappedMetaVaultOracle
} from "silo-oracles/contracts/custom/wrappedMetaVaultOracle/WrappedMetaVaultOracleAdapter.sol";
import {
    IAggregatorInterfaceMinimal
} from "silo-oracles/contracts/custom/wrappedMetaVaultOracle/interfaces/IAggregatorInterfaceMinimal.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --ffi --match-contract WrappedMetaVaultOracleAdapterTest
*/
contract WrappedMetaVaultOracleAdapterTest is Test {
    uint256 constant TEST_BLOCK = 33323452;
    WrappedMetaVaultOracleAdapter adapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), TEST_BLOCK);

        WrappedMetaVaultOracleAdapterDeploy deploy = new WrappedMetaVaultOracleAdapterDeploy();
        deploy.disableDeploymentsSync();
        deploy.setFeedKey("wmetaUSD_USD_wMetaVault_aggregator");

        adapter = deploy.run();
    }

    function test_WrappedMetaVaultOracleAdapter_constructor() public view {
        assertEq(address(adapter.FEED()), 0x440A6bf579069Fa4e7C3C9fe634B34D2C78C584c, "feed is expected");
        assertEq(adapter.DECIMALS(), adapter.FEED().decimals(), "decimals are cached");

        assertEq(
            adapter.description(),
            "WrappedMetaVaultOracleAdapter for Wrapped Stability USD",
            "description has asset name"
        );
    }

    function test_WrappedMetaVaultOracleAdapter_constructor_reverts() public {
        IWrappedMetaVaultOracle underlyingFeed = IWrappedMetaVaultOracle(adapter.FEED());
        vm.expectRevert();
        new WrappedMetaVaultOracleAdapter(IWrappedMetaVaultOracle(address(1)));

        vm.mockCall(
            address(underlyingFeed),
            abi.encodeWithSelector(IAggregatorInterfaceMinimal.latestAnswer.selector),
            abi.encode(0)
        );

        vm.expectRevert(WrappedMetaVaultOracleAdapter.FeedHasZeroPrice.selector);
        new WrappedMetaVaultOracleAdapter(underlyingFeed);
    }

    function test_WrappedMetaVaultOracleAdapter_decimals() public view {
        IWrappedMetaVaultOracle underlyingFeed = adapter.FEED();
        assertEq(adapter.decimals(), underlyingFeed.decimals());
        assertEq(adapter.decimals(), adapter.DECIMALS());
        assertEq(adapter.decimals(), 8);
    }

    function test_WrappedMetaVaultOracleAdapter_latestRoundData_compareToOriginalRate() public view {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = adapter.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, adapter.FEED().latestAnswer());
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_WrappedMetaVaultOracleAdapter_latestRoundData_sanityCheck() public view {
        ( ,int256 answer,,,) = adapter.latestRoundData();

        assertEq(answer, 1.00144500e8, "USD vault price is close to dollar");
    }
}
