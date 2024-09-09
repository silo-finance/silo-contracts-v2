// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function getSiloDataInterestRateTimestamp() external view returns (uint256) {
        return siloData.interestRateTimestamp;
    }

    function getSiloDataDaoAndDeployerFees() external view returns (uint256) {
        return siloData.daoAndDeployerFees;
    }

    function getFlashloanFee0() external view returns (uint256) {
        (,, uint256 flashloanFee, ) = sharedStorage.siloConfig.getFeesWithAsset(address(this));
        return flashloanFee;
    }

    function getFlashloanFee1() external view returns (uint256) {
        (
            , ISiloConfig.ConfigData memory otherConfig,
        ) = sharedStorage.siloConfig.getConfigs(address(this), address(0), 0);

        return otherConfig.flashloanFee;
    }

    function reentrancyGuardEntered() external view returns (bool) {
        return sharedStorage.siloConfig.crossReentrancyGuardEntered();
    }

    function getDaoFee() external view returns (uint256) {
        (uint256 daoFee,,, ) = sharedStorage.siloConfig.getFeesWithAsset(address(this));
        return daoFee;
    }

    function getDeployerFee() external view returns (uint256) {
        (, uint256 deployerFee,, ) = sharedStorage.siloConfig.getFeesWithAsset(address(this));
        return deployerFee;
    }

    function getLTV(address borrower) external view returns (uint256) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = SiloSolvencyLib.getOrderedConfigs(this, config, borrower);
        
        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(borrower);
        
        return SiloSolvencyLib.getLtv(
            collateralConfig, debtConfig, borrower, ISilo.OracleType.MaxLtv, AccrueInterestInMemory.Yes, debtShareBalance
        );
    }

    function getAssetsDataForLtvCalculations(address borrower) external view returns (SiloSolvencyLib.LtvData memory) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = SiloSolvencyLib.getOrderedConfigs(this, config, borrower);
        
        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(borrower);
        
        return SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig, debtConfig, borrower, ISilo.OracleType.MaxLtv, AccrueInterestInMemory.Yes, debtShareBalance
        );
    }
}
