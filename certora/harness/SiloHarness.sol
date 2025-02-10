// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Views} from "silo-core/contracts/lib/Views.sol";
import {ShareTokenLib} from "silo-core/contracts//lib/ShareTokenLib.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    // TODO: this function is no longer needed
    function getSiloDataInterestRateTimestamp() external view returns (
        uint64 interestRateTimestamp
    ) {
        (, interestRateTimestamp, , , ) = Views.getSiloStorage();
    }

    // TODO: this function is no longer needed
    // TODO: verify that daoAndDeployerRevenue is the same as the old daoAndDeployerFee!
    function getSiloDataDaoAndDeployerRevenue() external view returns (
        uint192 daoAndDeployerRevenue
    ) {
        (daoAndDeployerRevenue, , , , ) = Views.getSiloStorage();
    }

    // TODO: this function is no longer needed
    function getFlashloanFee0() external view returns (uint256) {
        (,, uint256 flashloanFee, ) = ShareTokenLib.siloConfig().getFeesWithAsset(address(this));
        return flashloanFee;
    }

    // TODO: this function is no longer needed
    function reentrancyGuardEntered() external view returns (bool) {
        return ShareTokenLib.siloConfig().reentrancyGuardEntered();
    }

    // TODO: this function is no longer needed
    function getDaoFee() external view returns (uint256) {
        (uint256 daoFee,,, ) = ShareTokenLib.siloConfig().getFeesWithAsset(address(this));
        return daoFee;
    }

    // TODO: this function is no longer needed
    function getDeployerFee() external view returns (uint256) {
        (, uint256 deployerFee,, ) = ShareTokenLib.siloConfig().getFeesWithAsset(address(this));
        return deployerFee;
    }

    function getLTV(address borrower) external view returns (uint256) {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = ShareTokenLib.siloConfig().getConfigsForSolvency(borrower);
        // SiloSolvencyLib.getOrderedConfigs(this, config, borrower);
        
        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(borrower);
        
        return SiloSolvencyLib.getLtv(
            collateralConfig,
            debtConfig,
            borrower,
            ISilo.OracleType.MaxLtv,
            AccrueInterestInMemory.Yes,
            debtShareBalance
        );
    }

    function getAssetsDataForLtvCalculations(
        address borrower
    ) external view returns (SiloSolvencyLib.LtvData memory) {
        uint256 action;
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = ShareTokenLib.siloConfig().getConfigsForSolvency(borrower);
        
        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(borrower);
        
        return SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig,
            debtConfig,
            borrower,
            ISilo.OracleType.MaxLtv,
            AccrueInterestInMemory.Yes,
            debtShareBalance
        );
    }
    
    function getTransferWithChecks() external view returns (bool) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        return $.transferWithChecks;
    }
    


    function getSiloFromStorage() external view returns (ISilo) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        return $.silo;
    }
    
}
