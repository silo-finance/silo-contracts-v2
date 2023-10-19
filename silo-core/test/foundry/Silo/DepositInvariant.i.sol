// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloHandler} from "../_common/SiloHandler.sol";
import {SiloInvariants} from "../_common/SiloInvariants.sol";


/*
    forge test -vv --ffi --mc DepositInvariantTest
*/
contract DepositInvariantTest is Test {
    SiloInvariants invariants;

    address user1 = address(0xabc01);
    address user2 = address(0xabc02);
    address user3 = address(0xabc03);

    function setUp() public {
        MintableToken token0 = new MintableToken();
        MintableToken token1 = new MintableToken();

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);

        SiloFixture siloFixture = new SiloFixture();
        (
            ISiloConfig siloConfig, ISilo silo0, ISilo silo1,,
        ) = siloFixture.deploy_local(overrides);

        SiloHandler siloHandler = new SiloHandler(silo0, silo1, token0, token1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = SiloHandler.deposit.selector;
        selectors[1] = SiloHandler.depositType.selector;

        targetContract(address(siloHandler));

        targetSelector(FuzzSelector(address(siloHandler), selectors));

        targetSender(user1);
        targetSender(user2);
        targetSender(user3);

        invariants = new SiloInvariants(siloConfig, silo0, silo1, token0, token1);
    }

    /*
    forge test -vv --ffi --mt invariant_silo_deposit
    */
    /// forge-config: core.invariant.runs = 100
    /// forge-config: core.invariant.depth = 15
    /// forge-config: core.invariant.fail-on-revert = false
    function invariant_silo_deposit() public {
        invariants.siloInvariant_userIsSolvent(user1);
        invariants.siloInvariant_userIsSolvent(user2);
        invariants.siloInvariant_userIsSolvent(user3);

        invariants.siloInvariant_balanceOfSiloMustBeEqToAssets();
        invariants.siloInvariant_whenNoInterestSharesEqAssets();
    }
}
