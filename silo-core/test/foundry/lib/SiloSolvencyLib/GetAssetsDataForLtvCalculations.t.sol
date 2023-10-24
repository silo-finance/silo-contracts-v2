// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";

import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {GetAssetsDataForLtvCalculationsTestData} from
    "silo-core/test/foundry/data-readers/GetAssetsDataForLtvCalculationsTestData.sol";
import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloMock} from "silo-core/test/foundry/_mocks/SiloMock.sol";
import {InterestRateModelMock} from "silo-core/test/foundry/_mocks/InterestRateModelMock.sol";

contract SiloFactoryHelper is SiloFactory {
    function copyConfig(ISiloConfig.InitData memory _initData)
        external
        pure
        returns (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1)
    {
        return _copyConfig(_initData);
    }
}

// forge test -vv --ffi --mc GetSharesAndTotalSupplyTest
contract GetAssetsDataForLtvCalculationsTest is Test {
    GetAssetsDataForLtvCalculationsTestData dataReader;
    SiloFactoryHelper siloFactoryHelper;

    address public protectedShareToken = makeAddr("ProtectedShareToken");
    address public collateralShareToken = makeAddr("CollateralShareToken");
    address public debtShareToken = makeAddr("DebtShareToken");
    address public borrowerAddr = makeAddr("Borrower");
    address public silo0 = makeAddr("Silo_0");
    address public silo1 = makeAddr("Silo_1");

    InterestRateModelMock interestRateModelMock = new InterestRateModelMock();

    function setUp() public {
        dataReader = new GetAssetsDataForLtvCalculationsTestData();
        siloFactoryHelper = new SiloFactoryHelper();
    }

    function getData(GetAssetsDataForLtvCalculationsTestData.ScenarioData memory scenario)
        public
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            address borrower,
            ISilo.OracleType oracleType,
            ISilo.AccrueInterestInMemory accrueInMemory,
            uint256 cachedShareDebtBalance
        )
    {
        { // stack too deep
            ISiloConfig.InitData memory initData;

            initData.maxLtvOracle0 = address(uint160(scenario.input.collateralConfig.maxLtvOracle));
            initData.solvencyOracle0 = address(uint160(scenario.input.collateralConfig.solvencyOracle));
            initData.interestRateModel0 = interestRateModelMock.ADDRESS();
            initData.deployerFeeInBp = scenario.input.collateralConfig.deployerFeeInBp;

            initData.maxLtvOracle1 = address(uint160(scenario.input.debtConfig.maxLtvOracle));
            initData.solvencyOracle1 = address(uint160(scenario.input.debtConfig.solvencyOracle));
            initData.interestRateModel1 = interestRateModelMock.ADDRESS();

            (collateralConfig, debtConfig) = siloFactoryHelper.copyConfig(initData);
        }

        collateralConfig.protectedShareToken = protectedShareToken;
        collateralConfig.collateralShareToken = collateralShareToken;
        collateralConfig.daoFeeInBp = scenario.input.collateralConfig.daoFeeInBp;
        collateralConfig.silo = silo0;

        debtConfig.debtShareToken = debtShareToken;
        debtConfig.silo = silo1;

        TokenMock protectedShareTokenMock = new TokenMock(vm, protectedShareToken);
        protectedShareTokenMock.balanceOfMock(borrowerAddr, scenario.input.collateralConfig.protectedShareBalanceOf);
        protectedShareTokenMock.totalSupplyMock(scenario.input.collateralConfig.protectedShareTotalSupply);

        TokenMock collateralShareTokenMock = new TokenMock(vm, collateralShareToken);
        collateralShareTokenMock.balanceOfMock(borrowerAddr, scenario.input.collateralConfig.collateralShareBalanceOf);
        collateralShareTokenMock.totalSupplyMock(scenario.input.collateralConfig.collateralShareTotalSupply);
        interestRateModelMock.getCompoundInterestRateMock(
            silo0, block.timestamp, scenario.input.collateralConfig.compoundInterestRate
        );

        TokenMock debtShareTokenMock = new TokenMock(vm, debtShareToken);
        if (scenario.input.debtConfig.cachedBalance) {
            cachedShareDebtBalance = scenario.input.debtConfig.debtShareBalanceOf;
        } else {
            debtShareTokenMock.balanceOfMock(borrowerAddr, scenario.input.debtConfig.debtShareBalanceOf);
        }
        debtShareTokenMock.totalSupplyMock(scenario.input.debtConfig.debtShareTotalSupply);

        SiloMock siloMock0 = new SiloMock(vm, silo0);
        siloMock0.getCollateralAssetsMock(scenario.input.collateralConfig.totalCollateralAssets);

        siloMock0.getCollateralAndProtectedAssetsMock(
            scenario.input.collateralConfig.totalCollateralAssets,
            scenario.input.collateralConfig.totalProtectedAssets
        );
        siloMock0.getDebtAssetsMock(scenario.input.collateralConfig.totalDebtAssets);

        SiloMock siloMock1 = new SiloMock(vm, silo1);
        siloMock1.getDebtAssetsMock(scenario.input.debtConfig.totalDebtAssets);
        interestRateModelMock.getCompoundInterestRateMock(
            silo1, block.timestamp, scenario.input.debtConfig.compoundInterestRate
        );

        borrower = borrowerAddr;

        oracleType = keccak256(bytes(scenario.input.oracleType)) == keccak256(bytes("solvency"))
            ? ISilo.OracleType.Solvency
            : ISilo.OracleType.MaxLtv;

        accrueInMemory = scenario.input.accrueInMemory
            ? ISilo.AccrueInterestInMemory.Yes
            : ISilo.AccrueInterestInMemory.No;
    }

    /*
    forge test -vv --ffi --mt test_getAssetsDataForLtvCalculations_scenarios
    */
    function test_getAssetsDataForLtvCalculations_scenarios() public {
        GetAssetsDataForLtvCalculationsTestData.ScenarioData[] memory scenarios = dataReader.getScenarios();

        for (uint256 index = 0; index < scenarios.length; index++) {
            (
                ISiloConfig.ConfigData memory collateralConfig,
                ISiloConfig.ConfigData memory debtConfig,
                address borrower,
                ISilo.OracleType oracleType,
                ISilo.AccrueInterestInMemory accrueInMemory,
                uint256 cachedShareDebtBalance
            ) = getData(scenarios[index]);

            SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
                collateralConfig, debtConfig, borrower, oracleType, accrueInMemory, cachedShareDebtBalance
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
