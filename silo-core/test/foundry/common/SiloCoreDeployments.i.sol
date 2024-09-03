// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloCoreDeployments, SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc SiloCoreDeploymentsTest
*/
contract SiloCoreDeploymentsTest is SiloLittleHelper, Test {
    string constant _networkName = "optimism";

    function setUp() public {
        AddrLib.init();
    }

    /*
    forge test -vv --ffi --mt test_get_exists
    */
    function test_get_exists_anvil() public {
        _setUpLocalFixture();

        address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, "anvil");
        assertEq(addr, 0xB6AdBb29f2D8ae731C7C72036A7FD5A7E970B198, "expect valid address anvil");
    }

    function test_get_exists_optimism() public {
        address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, "optimism");
        assertEq(addr, 0x01c6dc3bD8B175a9494F00b6D224b14EdC67CD34, "expect valid address Optimism");
    }

    function test_get_exists_arbitrum_one() public {
        address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, "arbitrum_one");
        assertEq(addr, 0x8C1b49B1A45d9FD50c5846a6Cd19a5ADaA376B1B, "expect valid address on Arbitrum");
    }

   function test_get_contractNotExists() public {
       address addr = SiloCoreDeployments.get("not.exist", _networkName);
       assertEq(addr, address(0), "expect to return 0");
   }

   function test_get_invalidNetwork() public {
       address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, "abcd");
       assertEq(addr, address(0), "expect to return 0");
   }
}
