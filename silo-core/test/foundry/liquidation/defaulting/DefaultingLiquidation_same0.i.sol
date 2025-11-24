// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {DefaultingLiquidationCommon} from "./DefaultingLiquidationCommon.sol";

/*
tests for same asset borrow, non-borrowable token is 0
*/
contract DefaultingLiquidationSame0Test is DefaultingLiquidationCommon {
    using SiloLensLib for ISilo;

    function setUp() public override {
        super.setUp();

        (address collateralAsset, address debtAsset) = _getTokens();

        assertEq(
            collateralAsset,
            debtAsset,
            "[crosscheck] collateral and debt assets should be the same for same asset case"
        );

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();
        assertEq(address(collateralSilo), address(debtSilo), "[crosscheck] silos must be the same for this case");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_bothLiquidationsResultsMatch_insolvent_fuzz -vv --mc DefaultingLiquidationSame1Test
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_bothLiquidationsResultsMatch_insolvent_fuzz(
        uint64 _priceDropPercentage, // not important because same asset
        uint32 _warp,
        uint48 _collateral,
        uint48 _protected
    ) public override {
        super.test_bothLiquidationsResultsMatch_insolvent_fuzz(_priceDropPercentage, _warp, _collateral, _protected);
    }

    // CONFIGURATION

    function _getSilos() internal view override returns (ISilo collateralSilo, ISilo debtSilo) {
        collateralSilo = silo0;
        debtSilo = silo0;
    }

    function _getTokens() internal view override returns (address collateralAsset, address debtAsset) {
        collateralAsset = address(token0);
        debtAsset = address(token0);
    }

    function _maxBorrow(address _borrower) internal view override returns (uint256) {
        (, ISilo debtSilo) = _getSilos();

        try debtSilo.maxBorrowSameAsset(_borrower) returns (uint256 _max) {
            return _max;
        } catch {
            return 0;
        }
    }

    function _executeBorrow(address _borrower, uint256 _amount) internal override returns (bool success) {
        (, ISilo debtSilo) = _getSilos();
        vm.prank(_borrower);

        try debtSilo.borrowSameAsset(_amount, _borrower, _borrower) {
            success = true;
        } catch {
            success = false;
        }
    }

    function _useConfigName() internal pure override returns (string memory) {
        return SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING0;
    }

    function _useSameAssetPosition() internal pure override returns (bool) {
        return true;
    }
}
