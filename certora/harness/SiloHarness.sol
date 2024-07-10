// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function getSiloDataInterestRateTimestamp() external view returns (uint256) {
        return _siloData.interestRateTimestamp;
    }

    function getSiloDataDaoAndDeployerFees() external view returns (uint256) {
        return _siloData.daoAndDeployerFees;
    }

    function getFlashloanFee0() external view returns (uint256) {
        (,, uint256 flashloanFee, ) = _sharedStorage.siloConfig.getFeesWithAsset(address(this));
        return flashloanFee;
    }

    function getFlashloanFee1() external view returns (uint256) {
        (
            , ISiloConfig.ConfigData memory otherConfig,
        ) = _sharedStorage.siloConfig.getConfigs(address(this), address(0), 0);

        return otherConfig.flashloanFee;
    }

    function reentrancyGuardEntered() external view returns (bool) {
        (bool entered, ) = _sharedStorage.siloConfig.crossReentrantStatus();
        return entered;
    }

    function reentrancyGuardStatus() external view returns (uint256) {
        (bool entered, uint256 status) = _sharedStorage.siloConfig.crossReentrantStatus();
        return status;
    }

    function getDaoFee() external view returns (uint256) {
        (uint256 daoFee,,, ) = _sharedStorage.siloConfig.getFeesWithAsset(address(this));
        return daoFee;
    }

    function getDeployerFee() external view returns (uint256) {
        (, uint256 deployerFee,, ) = _sharedStorage.siloConfig.getFeesWithAsset(address(this));
        return deployerFee;
    }

    function getLTV(address borrower) external view returns (uint256) {
        uint256 action;
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig, ISiloConfig.DebtInfo memory debtInfo
        ) = 
        _sharedStorage.siloConfig.getConfigs(address(this), borrower, action);
        // SiloSolvencyLib.getOrderedConfigs(this, config, borrower);
        
        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(borrower);
        
        return SiloSolvencyLib.getLtv(
            collateralConfig, debtConfig, borrower, ISilo.OracleType.MaxLtv, AccrueInterestInMemory.Yes, debtShareBalance
        );
    }

    function getAssetsDataForLtvCalculations(address borrower) external view returns (SiloSolvencyLib.LtvData memory) {
        uint256 action;
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig, ISiloConfig.DebtInfo memory debtInfo
        ) = 
        _sharedStorage.siloConfig.getConfigs(address(this), borrower, action);
        
        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(borrower);
        
        return SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig, debtConfig, borrower, ISilo.OracleType.MaxLtv, AccrueInterestInMemory.Yes, debtShareBalance
        );
    }

    function wasCalled_crossNonReentrantBefore() external view returns (bool) {
        bool res = _sharedStorage.siloConfig.wasCalled_crossNonReentrantBefore();
        return res;
    }

    function wasCalled_crossNonReentrantAfter() external view returns (bool) {
        bool res = _sharedStorage.siloConfig.wasCalled_crossNonReentrantAfter();
        return res;
    }
}
