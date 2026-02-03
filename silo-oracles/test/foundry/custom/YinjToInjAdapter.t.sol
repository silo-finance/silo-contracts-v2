// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {YinjToInjAdapter} from "silo-oracles/contracts/custom/yINJ/YinjToInjAdapter.sol";
import {IYInjPriceOracle} from "silo-oracles/contracts/custom/yINJ/interfaces/IYInjPriceOracle.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

interface IBankModule {
    function mint(address recipient, uint256 amount) external payable returns (bool);
    function totalSupply(address) external view returns (uint256);
}

/*
    FOUNDRY_PROFILE=oracles ../injective-foundry/target/release/forge test -vvv --match-contract YinjToInjAdapterTest
*/
contract YinjToInjAdapterTest is Test {
    IYInjPriceOracle public constant ORACLE = IYInjPriceOracle(0x072fB925014B45dec604A6c44f85DAf837653056);
    address public constant BANK_PRECOMPILE = address(0x64);
    IERC20Metadata public constant YINJ = IERC20Metadata(0x2d6E0e0c209D79b43f5d3D62e93D6A9f1e9317BD);
    IERC20Metadata public constant BYINJ = IERC20Metadata(0x913DD99a3326ecaB24A26B817f707CaE07Df7e45);

    // On-chain state for block 152793957
    uint256 public constant YINJ_TOTAL_SUPPLY = 225177260588439321975142;
    uint256 public constant BYINJ_TOTAL_SUPPLY = 231823129690205125835646;
    uint256 public constant ORACLE_RATE = 1.029513944189562651e18;

    YinjToInjAdapter public adapter;

    function setUp() public {
        // Forking at the latest block, because forking at block started failing in few weeks. Most likely,
        // the depth of blocks for an archive node is limited.
        vm.createSelectFork(vm.envString("RPC_INJECTIVE"));

        // Following mocking is required to build a valid on-chain state. This solution solves the issue with
        // non-contract calls errors at bank module 0x64.
        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.totalSupply.selector, YINJ),
            abi.encode(YINJ_TOTAL_SUPPLY)
        );

        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.totalSupply.selector, BYINJ),
            abi.encode(BYINJ_TOTAL_SUPPLY)
        );

        adapter = new YinjToInjAdapter(ORACLE);
    }

    function test_YinjToInjAdapter_oracleMockedStateIsValid() public view {
        assertEq(YINJ.totalSupply(), YINJ_TOTAL_SUPPLY, "Total supply for yINJ is expected");
        assertEq(BYINJ.totalSupply(), BYINJ_TOTAL_SUPPLY, "Total supply for byINJ is expected");
        assertEq(ORACLE.getExchangeRate(), ORACLE_RATE, "Oracle exchange rate is expected");
    }

    function test_YinjToInjAdapter_constructor() public view {
        assertEq(address(adapter.ORACLE()), address(ORACLE), "Oracle is set in constructor");
        assertEq(adapter.ORACLE_DECIMALS(), 18, "Oracle decimals are 18");

        assertTrue(
            Strings.equal(adapter.description(), "yINJ / INJ adapter for YInjPriceOracle"),
            "quote token is INJ in description"
        );
    }

    function test_YinjToInjAdapter_decimals() public view {
        assertEq(adapter.decimals(), 18, "Oracle decimals are 18");
        assertEq(adapter.decimals(), adapter.ORACLE_DECIMALS(), "Oracle decimals equal to underlying decimals");
    }

    function test_YinjToInjAdapter_constructor_reverts() public {
        vm.expectRevert();
        new YinjToInjAdapter(IYInjPriceOracle(address(YINJ)));

        vm.expectRevert(YinjToInjAdapter.InvalidOracleAddress.selector);

        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.totalSupply.selector, BYINJ),
            abi.encode(0)
        );

        new YinjToInjAdapter(ORACLE);
    }

    function test_YinjToInjAdapter_getRoundData_reverts() public {
        vm.expectRevert(YinjToInjAdapter.NotImplemented.selector);
        adapter.getRoundData(0);
    }

    function test_YinjToInjAdapter_latestRoundData_equalToOriginalRate() public view {
        assertEq(address(adapter.ORACLE()), address(ORACLE), "Oracle is set in constructor");

        (, int256 answer,,,) = adapter.latestRoundData();

        assertEq(uint256(answer), ORACLE.getExchangeRate(), "Answer is equal to the underlying oracle's rate");
        assertEq(uint256(answer), ORACLE_RATE, "Answer is equal to an expected rate");
    }
    function test_YinjToInjAdapter_latestRoundData_roundsAndTimestamps() public view {
        assertEq(address(adapter.ORACLE()), address(ORACLE), "Oracle is set in constructor");

        (
            uint80 roundId,
            ,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = adapter.latestRoundData();

        assertEq(roundId, 1, "roundId is 1");
        assertEq(startedAt, block.timestamp, "startedAt timestamp is block.timestamp");
        assertEq(updatedAt, block.timestamp, "startedAt timestamp is block.timestamp");
        assertEq(answeredInRound, 1, "answeredInRound is 1");

        assertEq(adapter.version(), 1, "version() is 1");
    }
}
