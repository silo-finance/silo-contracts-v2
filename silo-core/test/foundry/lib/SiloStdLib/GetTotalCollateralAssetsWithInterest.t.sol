// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloStdLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloMock} from "../../_mocks/SiloMock.sol";
import {ShareTokenMock} from "../../_mocks/ShareTokenMock.sol";
import {InterestRateModelMock} from "../../_mocks/InterestRateModelMock.sol";


// forge test -vv --mc GetTotalAssetsWithInterestTest
contract GetTotalAssetsWithInterestTest is Test {
    SiloMock immutable SILO;
    ShareTokenMock immutable SHARE_TOKEN;
    InterestRateModelMock immutable INTEREST_RATE_MODEL;

    constructor () {
        SILO = new SiloMock(vm);
        SHARE_TOKEN = new ShareTokenMock(vm);
        INTEREST_RATE_MODEL = new InterestRateModelMock(vm);
    }

    /*
    forge test -vv --mt test_getTotalCollateralAssetsWithInterest
    */
    function test_getTotalCollateralAssetsWithInterest() public {
        address silo = SILO.ADDRESS();
        address interestRateModel = INTEREST_RATE_MODEL.ADDRESS();
        uint256 daoFeeInBp;
        uint256 deployerFeeInBp;

        SILO.getCollateralAssetsMock(0);
        SILO.getDebtAssetsMock(0);
        INTEREST_RATE_MODEL.getCompoundInterestRateMock(silo, block.timestamp, 0);
        assertEq(SiloStdLib.getTotalCollateralAssetsWithInterest(silo, interestRateModel, daoFeeInBp, deployerFeeInBp), 0);

        INTEREST_RATE_MODEL.getCompoundInterestRateMock(silo, block.timestamp, 0.01e18);
        assertEq(SiloStdLib.getTotalCollateralAssetsWithInterest(silo, interestRateModel, daoFeeInBp, deployerFeeInBp), 0);

        SILO.getCollateralAssetsMock(1000);
        assertEq(SiloStdLib.getTotalCollateralAssetsWithInterest(silo, interestRateModel, daoFeeInBp, deployerFeeInBp), 1000);

        SILO.getDebtAssetsMock(500);
        assertEq(SiloStdLib.getTotalCollateralAssetsWithInterest(silo, interestRateModel, daoFeeInBp, deployerFeeInBp), 1005);
    }
}
