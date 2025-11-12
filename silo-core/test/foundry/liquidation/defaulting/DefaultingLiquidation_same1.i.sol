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
tests for same asset borrow, non-borrowable token is 1
*/
contract DefaultingLiquidationSame1Test is DefaultingLiquidationCommon {
    using SiloLensLib for ISilo;

    // CONFIGURATION

    function _getSilos() internal view override returns (ISilo collateralSilo, ISilo debtSilo) {
        collateralSilo = silo1;
        debtSilo = silo1;
    }

    function _maxBorrow(address _borrower) internal view override returns (uint256) {
        (, ISilo debtSilo) = _getSilos();
        return debtSilo.maxBorrowSameAsset(_borrower);
    }

    function _executeBorrow(address _borrower, uint256 _amount) internal override {
        (, ISilo debtSilo) = _getSilos();
        vm.prank(_borrower);
        debtSilo.borrowSameAsset(_amount, _borrower, _borrower);
    }

    function _useConfigName() internal pure override returns (string memory) {
        return SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING1;
    }

    function _useSameAssetPosition() internal pure override returns (bool) {
        return true;
    }
}
