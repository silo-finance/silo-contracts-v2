// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";
import {SiloLiquidationLib} from "silo-core/contracts/lib/SiloLiquidationLib.sol";
import {SiloLiquidationExecLib} from "silo-core/contracts/lib/SiloLiquidationExecLib.sol";
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";

import {SiloMock} from "../../_mocks/SiloMock.sol";
import {InterestRateModelMock} from "../../_mocks/InterestRateModelMock.sol";
import {TokenMock} from "../../_mocks/TokenMock.sol";
import {GetExactLiquidationAmountsTestData} from "../../data-readers/GetExactLiquidationAmountsTestData.sol";


// forge test -vv --mc LiquidationPreviewTest
contract GetExactLiquidationAmountsHelper is Test {
    uint256 constant BASIS_POINTS = 1e4;
    uint64 constant LT = 0.8e4;

    SiloMock immutable SILO_A;
    SiloMock immutable SILO_B;

    TokenMock immutable TOKEN_A;
    TokenMock immutable C_SHARE_TOKEN_A;
    TokenMock immutable D_SHARE_TOKEN_A;
    TokenMock immutable P_SHARE_TOKEN_A;

    TokenMock immutable TOKEN_B;
    TokenMock immutable C_SHARE_TOKEN_B;
    TokenMock immutable D_SHARE_TOKEN_B;
    TokenMock immutable P_SHARE_TOKEN_B;

    InterestRateModelMock immutable INTEREST_RATE_MODEL;

    constructor () {
        SILO_A = new SiloMock(vm, makeAddr("SILO_A"));
        SILO_B = new SiloMock(vm, makeAddr("SILO_B"));

        TOKEN_A = new TokenMock(vm, makeAddr("TOKEN_A"));
        C_SHARE_TOKEN_A = new TokenMock(vm, makeAddr("C_SHARE_TOKEN_A"));
        D_SHARE_TOKEN_A = new TokenMock(vm, makeAddr("D_SHARE_TOKEN_A"));
        P_SHARE_TOKEN_A = new TokenMock(vm, makeAddr("P_SHARE_TOKEN_A"));

        TOKEN_B = new TokenMock(vm, makeAddr("TOKEN_B"));
        C_SHARE_TOKEN_B = new TokenMock(vm, makeAddr("C_SHARE_TOKEN_B"));
        D_SHARE_TOKEN_B = new TokenMock(vm, makeAddr("D_SHARE_TOKEN_B"));
        P_SHARE_TOKEN_B = new TokenMock(vm, makeAddr("P_SHARE_TOKEN_B"));

        INTEREST_RATE_MODEL = new InterestRateModelMock(vm);
    }

    function getExactLiquidationAmounts(
        uint128 _debtToCover,
        uint128 _collateralUserBalanceOf,
        uint128 _debtUserBalanceOf,
        uint32 _liquidationFeeInBp,
        bool _selfLiquidation

    ) external returns (uint256 fromCollateral, uint256 fromProtected, uint256 repayDebtAssets) {
        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) = _configs();
        uint256 sharesOffset = 10 ** 2;

        P_SHARE_TOKEN_A.balanceOfMock(makeAddr("borrower"), 0);
        P_SHARE_TOKEN_A.totalSupplyMock(0);
        SILO_A.getProtectedAssetsMock(0);

        C_SHARE_TOKEN_A.balanceOfMock(makeAddr("borrower"), _collateralUserBalanceOf * sharesOffset);
        C_SHARE_TOKEN_A.totalSupplyMock((2 ** 128 - 1) * sharesOffset);
        SILO_A.getCollateralAssetsMock(2 ** 128 - 1);

        D_SHARE_TOKEN_B.balanceOfMock(makeAddr("borrower"), _debtUserBalanceOf * sharesOffset);
        D_SHARE_TOKEN_B.totalSupplyMock(_debtUserBalanceOf * sharesOffset);
        SILO_B.getDebtAssetsMock(_debtUserBalanceOf);

        return SiloLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            makeAddr("borrower"),
            _debtToCover,
            _liquidationFeeInBp,
            _selfLiquidation
        );
    }

    function _configs()
        internal
        view
        returns (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig)
    {
        collateralConfig.silo = SILO_A.ADDRESS();
        collateralConfig.otherSilo = SILO_B.ADDRESS();
        collateralConfig.token = TOKEN_A.ADDRESS();
        collateralConfig.collateralShareToken = C_SHARE_TOKEN_A.ADDRESS();
        collateralConfig.protectedShareToken = P_SHARE_TOKEN_A.ADDRESS();
        collateralConfig.debtShareToken = D_SHARE_TOKEN_A.ADDRESS();
        collateralConfig.interestRateModel = INTEREST_RATE_MODEL.ADDRESS();

        collateralConfig.lt = LT;

        debtConfig.silo = SILO_B.ADDRESS();
        debtConfig.otherSilo = SILO_A.ADDRESS();
        debtConfig.token = TOKEN_B.ADDRESS();
        debtConfig.collateralShareToken = C_SHARE_TOKEN_B.ADDRESS();
        debtConfig.protectedShareToken = P_SHARE_TOKEN_B.ADDRESS();
        debtConfig.debtShareToken = D_SHARE_TOKEN_B.ADDRESS();
        debtConfig.interestRateModel = INTEREST_RATE_MODEL.ADDRESS();
    }
}


// forge test -vv --mc LiquidationPreviewTest
contract GetExactLiquidationAmountsTest is GetExactLiquidationAmountsHelper {
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

        P_SHARE_TOKEN_A.balanceOfMock(user, 0);
        P_SHARE_TOKEN_A.totalSupplyMock(0);
        SILO_A.getProtectedAssetsMock(0);

        C_SHARE_TOKEN_A.balanceOfMock(user, 0);
        C_SHARE_TOKEN_A.totalSupplyMock(0);
        SILO_A.getCollateralAssetsMock(0);

        D_SHARE_TOKEN_B.balanceOfMock(user, 0);
        D_SHARE_TOKEN_B.totalSupplyMock(0);
        SILO_B.getDebtAssetsMock(0);

        (
            uint256 fromCollateral, uint256 fromProtected, uint256 repayDebtAssets
        ) = SiloLiquidationExecLib.getExactLiquidationAmounts(collateralConfig, debtConfig, user, debtToCover, liquidationFeeInBp, selfLiquidation);

        assertEq(fromCollateral, 0);
        assertEq(fromProtected, 0);
        assertEq(repayDebtAssets, 0);
    }

    /*
    forge test -vv --mt test_getExactLiquidationAmounts_noOracle_loop
    */
    function test_getExactLiquidationAmounts_noOracle_loop() public {
        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) = _configs();

        GetExactLiquidationAmountsTestData.GELAData[] memory testDatas = new GetExactLiquidationAmountsTestData().getData();

        for (uint256 i; i < testDatas.length; i++) {
            GetExactLiquidationAmountsTestData.GELAData memory testData = testDatas[i];

            P_SHARE_TOKEN_A.balanceOfMock(testData.input.user, testData.mocks.protectedUserSharesBalanceOf);
            P_SHARE_TOKEN_A.totalSupplyMock(testData.mocks.protectedSharesTotalSupply);
            SILO_A.getProtectedAssetsMock(testData.mocks.siloTotalProtectedAssets);

            C_SHARE_TOKEN_A.balanceOfMock(testData.input.user, testData.mocks.collateralUserSharesBalanceOf);
            C_SHARE_TOKEN_A.totalSupplyMock(testData.mocks.collateralSharesTotalSupply);
            SILO_A.getCollateralAssetsMock(testData.mocks.siloTotalCollateralAssets);

            D_SHARE_TOKEN_B.balanceOfMock(testData.input.user, testData.mocks.debtUserSharesBalanceOf);
            D_SHARE_TOKEN_B.totalSupplyMock(testData.mocks.debtSharesTotalSupply);
            SILO_B.getDebtAssetsMock(testData.mocks.siloTotalDebtAssets);

            (
                uint256 fromCollateral, uint256 fromProtected, uint256 repayDebtAssets
            ) = SiloLiquidationExecLib.getExactLiquidationAmounts(
                collateralConfig,
                debtConfig,
                testData.input.user,
                testData.input.debtToCover,
                testData.input.liquidationFeeInBp,
                testData.input.selfLiquidation
            );

            // emit log_named_uint(string(abi.encodePacked("################ ", testData.name, " #")), i);
            assertEq(fromProtected, testData.output.fromProtected, "fromProtected");
            assertEq(fromCollateral, testData.output.fromCollateral, "fromCollateral");
            assertEq(repayDebtAssets, testData.output.repayDebtAssets, "repayDebtAssets");
        }
    }

    /*
    forge test -vv --mt test_getExactLiquidationAmounts_selfLiquidation_fuzz
    make sure self-liquidation can not make user insolvent
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_getExactLiquidationAmounts_selfLiquidation_fuzz(
        uint128 _debtToCover,
        uint128 _collateralUserBalanceOf,
        uint120 _debtUserBalanceOf
    ) public {
        vm.assume(_debtToCover > 0);
        vm.assume(_debtToCover <= _debtUserBalanceOf);
        vm.assume(_collateralUserBalanceOf > 0);

        // in this test we assume share is 1:1 assets 1:1 value
        uint256 ltvBefore = _debtUserBalanceOf * BASIS_POINTS / _collateralUserBalanceOf;

        // investigate "normal" cases, where LTV is <= LT, user is solvent
        vm.assume(ltvBefore <= LT);

        (
            uint256 collateralToLiquidate, uint256 ltvAfter, bool success, bytes4 errorType
        ) = _tryGetExactLiquidationAmounts(_debtToCover, _collateralUserBalanceOf, _debtUserBalanceOf, 0, true);

        // we want cases where we doing liquidation
        vm.assume(collateralToLiquidate != 0);

        if (success) {
            assertGe(ltvBefore, ltvAfter, "self liquidation can not make user less solvent than it was, because fee=0");

            if (ltvBefore <= LT) {
                assertLe(ltvAfter, LT, "self liquidation can not make user insolvent");
            }
        } else {
            assertFalse(true, "do we ever revert with our assumptions?");
            assertTrue(bytes4(errorType) == ISiloLiquidation.Insolvency.selector, "this is the only error we expect");
        }
    }

    /*
    forge test -vv --mt test_getExactLiquidationAmounts_liquidation_fuzz
    goal here is to check if we can get unexpected reverts
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_getExactLiquidationAmounts_liquidation_fuzz(
        uint128 _debtToCover,
        uint128 _collateralUserBalanceOf,
        uint128 _debtUserBalanceOf
    ) public {
        vm.assume(_debtToCover != 0);
        vm.assume(_debtToCover <= _debtUserBalanceOf);
        vm.assume(_collateralUserBalanceOf != 0);

        // in this test we assume share is 1:1 assets 1:1 value
        uint256 ltvBefore = uint256(_debtUserBalanceOf) * BASIS_POINTS / _collateralUserBalanceOf;

        // investigate "normal" cases, where LTV is <= 100%, if we have bad debt then this is already lost cause
        vm.assume(ltvBefore >= LT);
        vm.assume(ltvBefore <= BASIS_POINTS);

        (
            uint256 collateralToLiquidate,, bool success, bytes4 errorType
        ) = _tryGetExactLiquidationAmounts(_debtToCover, _collateralUserBalanceOf, _debtUserBalanceOf, 1, false);

        // we want cases where we do not revert
        vm.assume(success);
        // we want cases where we doing liquidation
        vm.assume(collateralToLiquidate != 0);

        if (success) {
            // there is nothing to check here
        } else {
            assertTrue(bytes4(errorType) == ISiloLiquidation.LiquidationTooBig.selector, "expect no other errors");
        }
    }

    function _tryGetExactLiquidationAmounts(
        uint128 _debtToCover,
        uint128 _collateralUserBalanceOf,
        uint128 _debtUserBalanceOf,
        uint32 _liquidationFeeInBp,
        bool _selfLiquidation
    ) internal returns (uint256 collateralToLiquidate, uint256 ltvAfter, bool success, bytes4 errorType) {
        try GetExactLiquidationAmountsHelper(this).getExactLiquidationAmounts(
            _debtToCover,
            _collateralUserBalanceOf,
            _debtUserBalanceOf,
            _liquidationFeeInBp,
            _selfLiquidation
        ) returns (uint256 fromCollateral, uint256 fromProtected, uint256 repayDebtAssets) {
            collateralToLiquidate = fromCollateral + fromProtected;
            success = true;

            ltvAfter = _collateralUserBalanceOf - fromCollateral == 0
                ? 0
                : uint256(_debtUserBalanceOf - repayDebtAssets) * BASIS_POINTS / uint256(_collateralUserBalanceOf - fromCollateral);
        } catch (bytes memory data) {
            errorType = bytes4(data);
        }
    }
}
