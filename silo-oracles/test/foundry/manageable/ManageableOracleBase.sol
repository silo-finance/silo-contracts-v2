// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ManageableOracleFactory} from "silo-oracles/contracts/manageable/ManageableOracleFactory.sol";
import {IManageableOracleFactory} from "silo-oracles/contracts/interfaces/IManageableOracleFactory.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {MockOracleFactory} from "silo-oracles/test/foundry/manageable/common/MockOracleFactory.sol";

/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleBase
 (base is abstract; run ManageableOracleBaseWithOracleTest or ManageableOracleBaseWithFactoryTest)
*/
abstract contract ManageableOracleBase is Test {
    address internal owner = makeAddr("Owner");
    uint32 internal constant timelock = 1 days;
    address internal baseToken;

    IManageableOracleFactory internal factory;
    SiloOracleMock1 internal oracleMock;

    function setUp() public {
        oracleMock = new SiloOracleMock1();
        factory = new ManageableOracleFactory();
        baseToken = address(new MintableToken(18));
    }

    /// @return manageableOracle Created oracle (via create with oracle or create with factory)
    function _createManageableOracle() internal virtual returns (ISiloOracle manageableOracle);

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_creation_emitsAllEvents
    */
    function test_ManageableOracle_creation_emitsAllEvents() public {
        address predictedAddress = factory.predictAddress(address(this), bytes32(0));

        vm.expectEmit(true, true, true, true, address(factory));
        emit IManageableOracleFactory.ManageableOracleCreated(predictedAddress, owner);

        vm.expectEmit(true, true, true, true);
        emit IManageableOracle.OwnershipTransferred(address(0), owner);

        vm.expectEmit(true, true, true, true);
        emit IManageableOracle.OracleUpdated(ISiloOracle(address(oracleMock)));

        vm.expectEmit(true, true, true, true);
        emit IManageableOracle.TimelockUpdated(timelock);

        _createManageableOracle();
    }
}
