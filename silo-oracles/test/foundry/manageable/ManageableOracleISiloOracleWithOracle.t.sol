// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {ManageableOracleISiloOracleTestBase} from
    "silo-oracles/test/foundry/manageable/ManageableOracleISiloOracleTestBase.sol";

/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleISiloOracleWithOracleTest
*/
contract ManageableOracleISiloOracleWithOracleTest is ManageableOracleISiloOracleTestBase {
    function _createManageableOracle() internal override returns (ISiloOracle manageableOracle) {
        manageableOracle = ISiloOracle(
            address(factory.create(ISiloOracle(address(oracleMock)), owner, timelock, baseToken, bytes32(0)))
        );
    }
}
