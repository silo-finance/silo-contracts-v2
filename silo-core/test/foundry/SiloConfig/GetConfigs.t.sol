// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";

/*
forge test -vv --mc SiloGetConfigsTest
*/
contract SiloGetConfigsTest is Test {
    address constant OTHER_SILO = makeAddr("otherSilo");
    address constant BORROWER = makeAddr("BORROWER");

    SiloConfig immutable siloConfig;

    constructor() {
        ISiloConfig.ConfigData memory configData0;
        configData0.silo = address(this);
        configData0.otherSilo = OTHER_SILO;
        configData0.token = address(1);

        ISiloConfig.ConfigData memory configData1;
        configData1.silo = OTHER_SILO;
        configData1.otherSilo = address(this);
        configData1.token = address(2);

        uint256 siloId = 1;

        siloConfig = new SiloConfig(siloId, configData0, configData1);
    }

    function test_getConfigs_noDebt_withdraw() public {
        bool sameToken = false;
        bool configForBorrow = false;

        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
            ISiloConfig.PositionInfo memory positionInfo
        ) = siloConfig.getConfigs(address(this), BORROWER, sameToken, configForBorrow);

        assertEq(collateral.silo, address(this), "withdrawing is always for collateral, from this silo");
        assertEq(debt.silo, address(0), "when no debt, debt config is not needed");
    }
}
