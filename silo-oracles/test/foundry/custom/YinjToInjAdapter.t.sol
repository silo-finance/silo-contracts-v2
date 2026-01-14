// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {YinjToInjAdapter} from "silo-oracles/contracts/custom/yINJ/YinjToInjAdapter.sol";
import {IYInjPriceOracle} from "silo-oracles/contracts/custom/yINJ/interfaces/IYInjPriceOracle.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vvv --match-contract YinjToInjAdapterTest
*/
contract YinjToInjAdapterTest is Test {
    uint256 constant TEST_BLOCK = 149351340;
    IYInjPriceOracle constant ORACLE = IYInjPriceOracle(0x072fB925014B45dec604A6c44f85DAf837653056);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_INJECTIVE"), TEST_BLOCK);
    }

    function test_YinjToInjAdapter_constructor() public {
        YinjToInjAdapter adapter = new YinjToInjAdapter(ORACLE);
        assertEq(address(adapter.ORACLE()), address(ORACLE), "Oracle is set in constructor");
    }
}
