// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ManageableOracleFactory} from "silo-oracles/contracts/manageable/ManageableOracleFactory.sol";
import {IManageableOracleFactory} from "silo-oracles/contracts/interfaces/IManageableOracleFactory.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleFactoryTest
*/
contract ManageableOracleFactoryTest is Test {
    ManageableOracleFactory internal factory;
    SiloOracleMock1 internal oracleMock;
    address internal owner;
    uint32 internal timelock;
    address internal baseToken;

    function setUp() public {
        oracleMock = new SiloOracleMock1();
        factory = new ManageableOracleFactory();
        owner = makeAddr("Owner");
        timelock = 1 days;
        baseToken = address(new MintableToken(18));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_predictAddress_matchesDeploy
    */
    function test_predictAddress_matchesDeploy() public {
        address predictedAddress1 = factory.predictAddress(address(this), bytes32(0));
        IManageableOracle oracle1 =
            factory.create(ISiloOracle(address(oracleMock)), owner, timelock, baseToken, bytes32(0));
        assertEq(address(oracle1), predictedAddress1, "invalid first predicted address");

        address predictedAddress2 = factory.predictAddress(address(this), bytes32(0));
        IManageableOracle oracle2 =
            factory.create(ISiloOracle(address(oracleMock)), owner, timelock, baseToken, bytes32(0));
        assertEq(address(oracle2), predictedAddress2, "invalid second predicted address");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_createdInFactory_afterCreate
    */
    function test_createdInFactory_afterCreate() public {
        IManageableOracle manageableOracle =
            factory.create(ISiloOracle(address(oracleMock)), owner, timelock, baseToken, bytes32(0));

        assertTrue(factory.createdInFactory(address(manageableOracle)), "oracle not in factory mapping");
    }
}
