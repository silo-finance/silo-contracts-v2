// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SiloStdLib} from "silo-core/contracts/lib/SiloStdLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloMock} from "../../_mocks/SiloMock.sol";
import {InterestRateModelMock} from "../../_mocks/InterestRateModelMock.sol";


// forge test -vv --mc GetTotalDebtAssetsWithInterestTest
contract GetTotalDebtAssetsWithInterestTest is Test {
    SiloMock immutable SILO;
    InterestRateModelMock immutable INTEREST_RATE_MODEL;

    constructor () {
        SILO = new SiloMock(address(0));
        INTEREST_RATE_MODEL = new InterestRateModelMock();
    }

    /*
    forge test -vv --mt test_getTotalDebtAssetsWithInterest
    */
    function test_getTotalDebtAssetsWithInterest() public {
        address silo = SILO.ADDRESS();
        address interestRateModel = INTEREST_RATE_MODEL.ADDRESS();

        SILO.totalMock(ISilo.AssetType.Debt, 0);
        INTEREST_RATE_MODEL.getCompoundInterestRateMock(silo, block.timestamp, 0);

        assertEq(SiloStdLib.getTotalDebtAssetsWithInterest(silo, interestRateModel), 0);

        INTEREST_RATE_MODEL.getCompoundInterestRateMock(silo, block.timestamp, 1e18);

        assertEq(SiloStdLib.getTotalDebtAssetsWithInterest(silo, interestRateModel), 0);

        SILO.totalMock(ISilo.AssetType.Debt, 1e18);
        INTEREST_RATE_MODEL.getCompoundInterestRateMock(silo, block.timestamp, 0);

        assertEq(SiloStdLib.getTotalDebtAssetsWithInterest(silo, interestRateModel), 1e18);

        SILO.totalMock(ISilo.AssetType.Debt, 1e18);
        INTEREST_RATE_MODEL.getCompoundInterestRateMock(silo, block.timestamp, 0.01e18);

        assertEq(SiloStdLib.getTotalDebtAssetsWithInterest(silo, interestRateModel), 1.01e18);
    }
}
