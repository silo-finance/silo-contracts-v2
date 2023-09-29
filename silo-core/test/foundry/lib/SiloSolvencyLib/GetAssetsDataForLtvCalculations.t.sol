// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";

import "silo-core/contracts/lib/SiloSolvencyLib.sol";

import {GetAssetsDataForLtvCalculationsTestData} from
    "silo-core/test/foundry/data-readers/GetAssetsDataForLtvCalculationsTestData.sol";
import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloMock} from "silo-core/test/foundry/_mocks/SiloMock.sol";
import {InterestRateModelMock} from "silo-core/test/foundry/_mocks/InterestRateModelMock.sol";

// forge test -vv --mc GetSharesAndTotalSupplyTest
contract GetAssetsDataForLtvCalculationsTest is Test {
    GetAssetsDataForLtvCalculationsTestData dataReader;

    address public protectedShareToken = address(10000001);
    address public collateralShareToken = address(10000002);
    address public debtShareToken = address(10000003);
    address public borrowerAddr = address(10000004);
    address public silo0 = address(10000005);
    address public silo1 = address(10000006);

    InterestRateModelMock interestRateModelMock = new InterestRateModelMock(vm);

    function setUp() public {
        dataReader = new GetAssetsDataForLtvCalculationsTestData();
    }

    function getData(GetAssetsDataForLtvCalculationsTestData.ScenarioData memory scenario)
        public
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            address borrower,
            ISilo.OracleType oracleType,
            ISilo.AccrueInterestInMemory accrueInMemory
        )
    {
        uint256 timestamp = 1;
        debtConfig.maxLtvOracle = address(uint160(scenario.input.debtConfig.maxLtvOracle));
        debtConfig.solvencyOracle = address(uint160(scenario.input.debtConfig.solvencyOracle));
        debtConfig.debtShareToken = debtShareToken;
        TokenMock debtShareTokenMock = new TokenMock(vm, debtShareToken);
        debtShareTokenMock.balanceOfMock(borrowerAddr, scenario.input.debtConfig.debtShareBalanceOf);
        debtShareTokenMock.totalSupplyMock(scenario.input.debtConfig.debtShareTotalSupply);
        debtConfig.silo = silo0;
        SiloMock siloMock0 = new SiloMock(vm, silo0);
        siloMock0.getDebtAssetsMock(scenario.input.debtConfig.totalDebtAssets);
        debtConfig.interestRateModel = interestRateModelMock.ADDRESS();
        interestRateModelMock.getCompoundInterestRateMock(
            silo0, timestamp, scenario.input.debtConfig.compoundInterestRate
        );

        collateralConfig.maxLtvOracle = address(uint160(scenario.input.collateralConfig.maxLtvOracle));
        collateralConfig.solvencyOracle = address(uint160(scenario.input.collateralConfig.solvencyOracle));
        collateralConfig.protectedShareToken = protectedShareToken;
        TokenMock protectedShareTokenMock = new TokenMock(vm, protectedShareToken);
        protectedShareTokenMock.balanceOfMock(borrowerAddr, scenario.input.collateralConfig.protectedShareBalanceOf);
        protectedShareTokenMock.totalSupplyMock(scenario.input.collateralConfig.protectedShareTotalSupply);
        collateralConfig.collateralShareToken = collateralShareToken;
        TokenMock collateralShareTokenMock = new TokenMock(vm, collateralShareToken);
        collateralShareTokenMock.balanceOfMock(borrowerAddr, scenario.input.collateralConfig.collateralShareBalanceOf);
        collateralShareTokenMock.totalSupplyMock(scenario.input.collateralConfig.collateralShareTotalSupply);
        collateralConfig.interestRateModel = interestRateModelMock.ADDRESS();
        interestRateModelMock.getCompoundInterestRateMock(
            silo1, timestamp, scenario.input.collateralConfig.compoundInterestRate
        );
        collateralConfig.daoFeeInBp = scenario.input.collateralConfig.daoFeeInBp;
        collateralConfig.deployerFeeInBp = scenario.input.collateralConfig.deployerFeeInBp;
        collateralConfig.silo = silo1;
        SiloMock siloMock1 = new SiloMock(vm, silo1);
        siloMock1.getProtectedAssetsMock(scenario.input.collateralConfig.totalProtectedAssets);
        siloMock1.getCollateralAssetsMock(scenario.input.collateralConfig.totalCollateralAssets);
        siloMock1.getDebtAssetsMock(scenario.input.collateralConfig.totalDebtAssets);

        borrower = borrowerAddr;
        oracleType = keccak256(bytes(scenario.input.oracleType)) == keccak256(bytes("solvency"))
            ? ISilo.OracleType.Solvency
            : ISilo.OracleType.MaxLtv;
        accrueInMemory =
            scenario.input.accrueInMemory ? ISilo.AccrueInterestInMemory.Yes : ISilo.AccrueInterestInMemory.No;
    }

    /*
    forge test -vv --mt test_getAssetsDataForLtvCalculations_scenarios
    */
    function test_getAssetsDataForLtvCalculations_scenarios() public {
        GetAssetsDataForLtvCalculationsTestData.ScenarioData[] memory scenarios = dataReader.getScenarios();

        for (uint256 index = 0; index < scenarios.length; index++) {
            (
                ISiloConfig.ConfigData memory collateralConfig,
                ISiloConfig.ConfigData memory debtConfig,
                address borrower,
                ISilo.OracleType oracleType,
                ISilo.AccrueInterestInMemory accrueInMemory
            ) = getData(scenarios[index]);
            SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
                collateralConfig, debtConfig, borrower, oracleType, accrueInMemory
            );

            assertEq(
                address(ltvData.collateralOracle),
                address(uint160(scenarios[index].expected.collateralOracle)),
                string.concat(Strings.toString(scenarios[index].id), " collateralOracle")
            );
            assertEq(
                address(ltvData.debtOracle),
                address(uint160(scenarios[index].expected.debtOracle)),
                string.concat(Strings.toString(scenarios[index].id), " debtOracle")
            );
            assertEq(
                ltvData.borrowerProtectedAssets,
                scenarios[index].expected.borrowerProtectedAssets,
                string.concat(Strings.toString(scenarios[index].id), " borrowerProtectedAssets")
            );
            assertEq(
                ltvData.borrowerCollateralAssets,
                scenarios[index].expected.borrowerCollateralAssets,
                string.concat(Strings.toString(scenarios[index].id), " borrowerCollateralAssets")
            );
            assertEq(
                ltvData.borrowerDebtAssets,
                scenarios[index].expected.borrowerDebtAssets,
                string.concat(Strings.toString(scenarios[index].id), " borrowerDebtAssets")
            );
        }
    }
}
