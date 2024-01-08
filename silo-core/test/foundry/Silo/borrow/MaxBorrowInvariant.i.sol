// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture, SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloHandler2} from "../../_common/SiloHandler2.sol";
import {SiloInvariants} from "../../_common/SiloInvariants.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";


/*
    forge test -vv --ffi --mc BorrowInvariantTest
*/
contract MaxBorrowInvariantTest is SiloLittleHelper, Test {
    SiloInvariants invariants;

    address user1 = makeAddr("User 1");
    address user2 = makeAddr("User 2");
    address user3 = makeAddr("User 3");

    function setUp() public {
        MintableToken token0 = new MintableToken();
        MintableToken token1 = new MintableToken();

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);

        SiloFixture siloFixture = new SiloFixture();
        (ISiloConfig siloConfig, ISilo silo0, ISilo silo1,,) = siloFixture.deploy_local(overrides);

        SiloHandler2 siloHandler = new SiloHandler2(silo0, silo1, token0, token1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = SiloHandler2.deposit.selector;
        selectors[1] = SiloHandler2.depositType.selector;
        selectors[2] = SiloHandler2.borrow.selector;
        selectors[3] = SiloHandler2.toTheFuture.selector;

        targetContract(address(siloHandler));

        targetSelector(FuzzSelector(address(siloHandler), selectors));

        targetSender(user1);
        targetSender(user2);
        targetSender(user3);

        invariants = new SiloInvariants(siloConfig, silo0, silo1, token0, token1);

        __init(token0, token1, silo0, silo1);
    }

    /*
    forge test -vv --ffi --mt invariant_silo_maxBorrow
    */
    /// forge-config: core.invariant.runs = 1000
    /// forge-config: core.invariant.depth = 15
    /// forge-config: core.invariant.fail-on-revert = true
    function invariant_silo_maxBorrow() public {
        invariants.siloInvariant_maxBorrowPossible(user1);
        invariants.siloInvariant_maxBorrowPossible(user2);
        invariants.siloInvariant_maxBorrowPossible(user3);
    }
}
