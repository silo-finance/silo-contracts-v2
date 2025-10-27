// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";
import {DummyOracle} from "../_common/DummyOracle.sol";

/*
    forge test -vv --ffi --mc SiloLensWithOracleTest
*/
contract SiloLensWithOracleTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    DummyOracle immutable solvencyOracle0;
    DummyOracle immutable maxLtvOracle0;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");

        token0 = new MintableToken(18);
        token1 = new MintableToken(18);

        solvencyOracle0 = new DummyOracle(1e18, address(token1));
        maxLtvOracle0 = new DummyOracle(1e18, address(token1));

        solvencyOracle0.setExpectBeforeQuote(true);
        maxLtvOracle0.setExpectBeforeQuote(true);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = address(solvencyOracle0);
        overrides.maxLtvOracle0 = address(maxLtvOracle0);
        overrides.configName = SiloConfigsNames.SILO_LOCAL_BEFORE_CALL;

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (, silo0, silo1,,, hook) = siloFixture.deploy_local(overrides);
        partialLiquidation = IPartialLiquidation(hook);
    }

    /*
        FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_SiloLensOracle_calculateProfitableLiquidation
    */
    function test_SiloLensOracle_calculateProfitableLiquidation() public {
        _depositForBorrow(100e18, depositor);

        _depositCollateral(100e18, borrower, false);
        _borrow(75e18, borrower);

        uint256 ltv = siloLens.getLtv(silo0, borrower);
        assertEq(ltv, 0.75e18, "price is 1:1 so LTV is 75%");

        solvencyOracle0.setPrice(0.5e18);
        ltv = siloLens.getLtv(silo0, borrower);
        assertEq(ltv, 1.5e18, "price drop");

        (uint256 collateralToLiquidate, uint256 debtToCover) =
            siloLens.calculateProfitableLiquidation(silo0, borrower);

        // we underestimate collateral by 2
        assertEq(collateralToLiquidate, 100e18 - 2, "collateralToLiquidate is 0 when position is solvent");
        // -1 for rounding
        assertEq(debtToCover, 50e18 - 50e18 * 0.05e18 / 1e18 - 1, "debtToCover is 0 when position is solvent");
    }
}
