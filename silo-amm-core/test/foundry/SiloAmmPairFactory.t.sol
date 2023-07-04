// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./helpers/Fixtures.sol";

import "../../contracts/SiloAmmPairFactory.sol";


/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract SiloAmmPairFactoryTest
*/
contract SiloAmmPairFactoryTest is Test, Fixtures {
    address constant TOKEN_0 = address(3);
    address constant TOKEN_1 = address(4);

    SiloAmmPairFactory immutable factory;

    constructor() {
        factory = new SiloAmmPairFactory();
    }

    function test_SiloAmmPairFactory_ping() public {
        assertEq(factory.siloAmmPairFactoryPing(), ISiloAmmPairFactory.siloAmmPairFactoryPing.selector);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPairFactory_createPair
    */
    function test_SiloAmmPairFactory_createPair() public {
        ISiloOracle oracle0;
        ISiloOracle oracle1;
        IFeeManager.FeeSetup memory fee = IFeeManager.FeeSetup(address(1), 0);
        address bridge;

        uint256 gasStart = gasleft();

        ISiloAmmPair pair = factory.createPair(
            address(this),
            TOKEN_0,
            TOKEN_1,
            oracle0,
            oracle1,
            bridge,
            fee,
            ammPriceConfig
        );

        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 2703490, "expected gas usage for createPair");
        assertEq(pair.silo(), address(this), "expected to set silo");
    }
}
