// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/SiloVerifier.s.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --match-contract SiloVerifierScriptTest --ffi
*/
contract SiloVerifierScriptTest is Test, SiloVerifier {
    ISiloConfig constant CONFIG_TWO_ORACLES = ISiloConfig(0xC1F3d4F5f734d6Dc9E7D4f639EbE489Acd4542ab);
    ISiloConfig constant CONFIG_ONE_ORACLE = ISiloConfig(0x78C246f67c8A6cE03a1d894d4Cf68004Bd55Deea);

    function setUp() public {
        vm.createSelectFork(string(abi.encodePacked(vm.envString("RPC_SONIC"))), 5599060);
        AddrLib.init();
    }

    function test_SiloVerifierScript_worksForSingleOracleConfigs() public {
        assertEq(_checkConfig(CONFIG_ONE_ORACLE, 10066, 10000), 0, "Should have no errors for single oracle configs");
    }

     function test_SiloVerifierScript_worksForTwoOracleConfigs() public {
        // both assets are bitcoins close to 100k
        assertEq(_checkConfig(CONFIG_TWO_ORACLES, 98_700, 99_200), 0, "Should have no errors for two oracle configs");
    }
}
