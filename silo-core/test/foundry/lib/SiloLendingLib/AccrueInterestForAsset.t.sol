// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {InterestRateModelMock} from "../../_mocks/InterestRateModelMock.sol";

// forge test -vv --mc AccrueInterestForAssetTest
contract AccrueInterestForAssetTest is Test {
    uint256 constant DECIMAL_POINTS = 1e18;

    /*
    forge test -vv --mt test_accrueInterestForAsset_initialCall_noData
    */
    function test_accrueInterestForAsset_initialCall_noData() public {
        uint256 accruedInterest = SiloLendingLib.accrueInterestForAsset(address(0), 0, 0);

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        assertEq(accruedInterest, 0, "zero when no data");
        assertEq($._total[AssetTypes.COLLATERAL].assets, 0, "totalCollateral 0");
        assertEq($._total[AssetTypes.DEBT].assets, 0, "totalDebt 0");
    }

    /*
    forge test -vv --mt test_accrueInterestForAsset_whenTimestampNotChanged
    */
    function test_accrueInterestForAsset_whenTimestampNotChanged() public {
        uint64 currentTimestamp = 222;
        vm.warp(currentTimestamp);

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        $._siloData.interestRateTimestamp = currentTimestamp;

        $._total[AssetTypes.COLLATERAL].assets = 1e18;
        $._total[AssetTypes.DEBT].assets = 1e18;

        uint256 accruedInterest = SiloLendingLib.accrueInterestForAsset(address(0), 0, 0);

        assertEq(accruedInterest, 0, "zero timestamp did not change");
        assertEq($._total[AssetTypes.COLLATERAL].assets, 1e18, "totalCollateral - timestamp did not change");
        assertEq($._total[AssetTypes.DEBT].assets, 1e18, "totalDebt - timestamp did not change");
    }

    /*
    forge test -vv --mt test_accrueInterestForAsset_withDataNoFee
    */
    function test_accrueInterestForAsset_withDataNoFee() public {
        uint64 oldTimestamp = 111;
        uint64 currentTimestamp = 222;
        vm.warp(currentTimestamp);

        uint256 rcomp = 0.01e18;

        InterestRateModelMock irm = new InterestRateModelMock();
        irm.getCompoundInterestRateAndUpdateMock(rcomp);

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        $._total[AssetTypes.COLLATERAL].assets = 1e18;
        $._total[AssetTypes.DEBT].assets = 0.5e18;
        $._siloData.interestRateTimestamp = oldTimestamp;

        uint256 accruedInterest = SiloLendingLib.accrueInterestForAsset(irm.ADDRESS(), 0, 0);

        assertEq(accruedInterest, 0.005e18, "accruedInterest");
        assertEq($._total[AssetTypes.COLLATERAL].assets, 1.005e18, "totalCollateral");
        assertEq($._total[AssetTypes.DEBT].assets, 0.505e18, "totalDebt");
        assertEq($._siloData.interestRateTimestamp, currentTimestamp, "interestRateTimestamp");
        assertEq($._siloData.daoAndDeployerFees, 0, "daoAndDeployerFees");
    }

    /*
    forge test -vv --mt test_accrueInterestForAsset_withDataWithFees
    */
    function test_accrueInterestForAsset_withDataWithFees() public {
        uint64 oldTimestamp = 111;
        uint64 currentTimestamp = 222;
        vm.warp(currentTimestamp);

        uint256 rcomp = 0.01e18;
        uint256 daoFee = 0.02e18;
        uint256 deployerFee = 0.03e18;

        InterestRateModelMock irm = new InterestRateModelMock();
        irm.getCompoundInterestRateAndUpdateMock(rcomp);

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        $._total[AssetTypes.COLLATERAL].assets = 1e18;
        $._total[AssetTypes.DEBT].assets = 0.5e18;
        $._siloData.interestRateTimestamp = oldTimestamp;

        uint256 accruedInterest = SiloLendingLib.accrueInterestForAsset(irm.ADDRESS(), daoFee, deployerFee);

        assertEq(accruedInterest, 0.005e18, "accruedInterest");
        assertEq(
            $._total[AssetTypes.COLLATERAL].assets,
            1e18 + accruedInterest * (DECIMAL_POINTS - daoFee - deployerFee) / DECIMAL_POINTS,
            "totalCollateral"
        );
        assertEq($._total[AssetTypes.DEBT].assets, 0.505e18, "totalDebt");
        assertEq($._siloData.interestRateTimestamp, currentTimestamp, "interestRateTimestamp");
        assertEq(
            $._siloData.daoAndDeployerFees,
            accruedInterest * (daoFee + deployerFee) / DECIMAL_POINTS,
            "daoAndDeployerFees"
        );
    }
}
