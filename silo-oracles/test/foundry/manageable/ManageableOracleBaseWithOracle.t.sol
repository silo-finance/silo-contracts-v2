// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";

import {ManageableOracleBase} from "silo-oracles/test/foundry/manageable/ManageableOracleBase.sol";

/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleBaseWithOracleTest
*/
contract ManageableOracleBaseWithOracleTest is ManageableOracleBase {
    function _createManageableOracle() internal override returns (IManageableOracle manageableOracle) {
        manageableOracle = factory.create(ISiloOracle(address(oracleMock)), owner, timelock, baseToken, bytes32(0));
    }
}
