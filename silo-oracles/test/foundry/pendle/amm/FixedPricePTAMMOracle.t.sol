// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {FixedPricePTAMMOracleFactory} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

contract FixedPricePTAMMOracleTest is Test {
    FixedPricePTAMMOracleFactory factory;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 67369870);

        factory = new FixedPricePTAMMOracleFactory();
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_PT_USDe_price --ffi -vv
    */
    function test_ptamm_PT_USDe_price() public {
        address pt = 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7;
        address usde = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // underlying token of PT

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            baseToken: pt,
            quoteToken: usde
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        uint256 price = oracle.quote(1e18, pt);

        assertEq(price, 0.980531592031963470e18, "PT price");
    }
}