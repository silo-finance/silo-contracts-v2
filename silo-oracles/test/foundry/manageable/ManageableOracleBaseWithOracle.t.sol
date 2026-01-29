// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {ManageableOracleBase} from "silo-oracles/test/foundry/manageable/ManageableOracleBase.sol";

/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleBaseWithOracleTest
*/
contract ManageableOracleBaseWithOracleTest is ManageableOracleBase {
    function _createManageableOracle() internal override returns (ISiloOracle manageableOracle) {
        manageableOracle = ISiloOracle(
            address(factory.create(ISiloOracle(address(oracleMock)), owner, timelock, baseToken, bytes32(0)))
        );
    }
}
