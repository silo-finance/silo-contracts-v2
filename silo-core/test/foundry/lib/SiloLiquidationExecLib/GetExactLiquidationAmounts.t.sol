// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLiquidationExecLib} from "silo-core/contracts/lib/SiloLiquidationExecLib.sol";

import "../../_mocks/SiloMock.sol";
import "../../_mocks/InterestRateModelMock.sol";
import "../../_mocks/ShareTokenMock.sol";

// forge test -vv --mc LiquidationPreviewTest
contract getExactLiquidationAmountsTest is Test {
    uint256 constant BASIS_POINTS = 1e4;

    SiloMock immutable SILO_A;
    SiloMock immutable SILO_B;

    TokenMock immutable TOKEN_A;
    TokenMock immutable C_TOKEN_A;
    TokenMock immutable D_TOKEN_A;
    TokenMock immutable P_TOKEN_A;

    TokenMock immutable TOKEN_B;
    TokenMock immutable C_TOKEN_B;
    TokenMock immutable D_TOKEN_B;
    TokenMock immutable P_TOKEN_B;

    InterestRateModelMock immutable INTEREST_RATE_MODEL;

    constructor () {
        SILO_A = new SiloMock(vm, address(0xaaaaaaaaaaaaaaaaaa5170));
        SILO_B = new SiloMock(vm, address(0xbbbbbbbbbbbbbbbbbb5170));

        TOKEN_A = new TokenMock(vm, address(0xaaaaaaaaaaaaaaaaaa));
        C_TOKEN_A = new TokenMock(vm, address(0xCC0aaaaaaaaaaaaaaaaaa));
        D_TOKEN_A = new TokenMock(vm, address(0xDD0aaaaaaaaaaaaaaaaaa));
        P_TOKEN_A = new TokenMock(vm, address(0xFF0aaaaaaaaaaaaaaaaaa));

        TOKEN_B = new TokenMock(vm, address(0xbbbbbbbbbbbbbbbbbb));
        C_TOKEN_B = new TokenMock(vm, address(0xCC0bbbbbbbbbbbbbbbbbb));
        D_TOKEN_B = new TokenMock(vm, address(0xDD0bbbbbbbbbbbbbbbbbb));
        P_TOKEN_B = new TokenMock(vm, address(0xFF0bbbbbbbbbbbbbbbbbb));

        INTEREST_RATE_MODEL = new InterestRateModelMock(vm);
    }

    function _configs()
        internal
        returns (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig)
    {
        collateralConfig.silo = SILO_A.ADDRESS();
        collateralConfig.otherSilo = SILO_B.ADDRESS();
        collateralConfig.token = TOKEN_A.ADDRESS();
        collateralConfig.collateralShareToken = C_TOKEN_A.ADDRESS();
        collateralConfig.protectedShareToken = P_TOKEN_A.ADDRESS();
        collateralConfig.debtShareToken = D_TOKEN_A.ADDRESS();
        collateralConfig.interestRateModel = INTEREST_RATE_MODEL.ADDRESS();

        debtConfig.silo = SILO_B.ADDRESS();
        debtConfig.otherSilo = SILO_A.ADDRESS();
        debtConfig.token = TOKEN_B.ADDRESS();
        debtConfig.collateralShareToken = C_TOKEN_B.ADDRESS();
        debtConfig.protectedShareToken = P_TOKEN_B.ADDRESS();
        debtConfig.debtShareToken = D_TOKEN_B.ADDRESS();
        debtConfig.interestRateModel = INTEREST_RATE_MODEL.ADDRESS();
    }
    /*
    forge test -vv --mt test_getExactLiquidationAmounts_noOracle_zero
    */
    function test_getExactLiquidationAmounts_noOracle_zero() public {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = _configs();

        address user;
        uint256 debtToCover;
        uint256 liquidationFeeInBp;
        bool selfLiquidation;

        P_TOKEN_A.balanceOfMock(user, 0);
        P_TOKEN_A.totalSupplyMock(0);
        SILO_A.getProtectedAssetsMock(0);

        C_TOKEN_A.balanceOfMock(user, 0);
        C_TOKEN_A.totalSupplyMock(0);
        SILO_A.getCollateralAssetsMock(0);

        D_TOKEN_B.balanceOfMock(user, 0);
        D_TOKEN_B.totalSupplyMock(0);
        SILO_B.getDebtAssetsMock(0);

        (
            uint256 fromCollateral, uint256 fromProtected, uint256 repayDebtAssets
        ) = SiloLiquidationExecLib.getExactLiquidationAmounts(collateralConfig, debtConfig, user, debtToCover, liquidationFeeInBp, selfLiquidation);

        assertEq(fromCollateral, 0);
        assertEq(fromProtected, 0);
        assertEq(repayDebtAssets, 0);
    }
}
