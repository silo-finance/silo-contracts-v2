// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture, SiloConfigOverride} from "../../../_common/fixtures/SiloFixture.sol";

import {MintableToken} from "../../../_common/MintableToken.sol";
import {SiloHandler2} from "../../../_common/SiloHandler2.sol";
import {SiloInvariants} from "../../../_common/SiloInvariants.sol";


/*
    forge test -vv --ffi --mc DepositInvariantTest
*/
contract DepositInvariantTest is Test {
    SiloInvariants invariants;
    SiloHandler2 siloHandler;

    MintableToken token0;
    MintableToken token1;

    ISilo silo0;
    ISilo silo1;
    ISiloConfig siloConfig;

    address user1 = makeAddr("User1");

    constructor() {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(overrides);

        siloHandler = new SiloHandler2(silo0, silo1, token0, token1);
    }

    function setUp() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = SiloHandler2.deposit.selector;

        targetContract(address(siloHandler));

        targetSelector(FuzzSelector(address(siloHandler), selectors));

        targetSender(user1);

        invariants = new SiloInvariants(siloConfig, silo0, silo1, token0, token1);
    }

    /*
    forge test -vv --ffi --mt invariant_silo_deposit
    */
    /// forge-config: core.invariant.runs = 100
    /// forge-config: core.invariant.depth = 15
    /// forge-config: core.invariant.fail-on-revert = true
    function invariant_silo_deposit() public {
        uint256 totalSupply = token0.totalSupply();
        if (totalSupply == 0) totalSupply = token1.totalSupply();
        if (totalSupply == 0) return;

        invariants.siloInvariant_userHasDeposit(user1);
    }
}
