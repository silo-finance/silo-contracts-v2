// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";
import {ISiloVaultBase} from "../../contracts/interfaces/ISiloVault.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc MulticallTest -vvv
*/
contract MulticallTest is IntegrationTest {
    bytes[] internal data;

    function testMulticall() public {
        data.push(abi.encodeCall(ISiloVaultBase.setCurator, (address(1))));
        data.push(abi.encodeCall(ISiloVaultBase.setIsAllocator, (address(1), true)));
        data.push(abi.encodeCall(ISiloVaultBase.submitTimelock, (ConstantsLib.MAX_TIMELOCK)));

        vm.prank(OWNER);
        vault.multicall(data);

        assertEq(vault.curator(), address(1));
        assertTrue(vault.isAllocator(address(1)));
        assertEq(vault.timelock(), ConstantsLib.MAX_TIMELOCK);
    }
}
