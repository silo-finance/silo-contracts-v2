// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { SiloSolvencyLib, ISiloConfig, ISilo} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import { ConfigForLib } from "./ConfigForLib.sol";

contract SiloSolvencyLibHarness is ConfigForLib {

    function isSolvent(
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) external view returns (bool) {
        ISiloConfig.ConfigData memory _collateralConfig = collateralConfig;
        ISiloConfig.ConfigData memory _debtConfig = debtConfig;
        ISiloConfig.DebtInfo memory _debtInfo = debtInfo;
        
        return SiloSolvencyLib.isSolvent
        (
            _collateralConfig,
            _debtConfig,
            _debtInfo,
            _borrower,
            _accrueInMemory
        );
    }

    function calculateLtv(
        SiloSolvencyLib.LtvData memory _ltvData, 
        address _collateralToken, 
        address _debtToken
    ) external view returns (uint256, uint256, uint256) {
        return SiloSolvencyLib.calculateLtv(_ltvData, _collateralToken, _debtToken);
    }

    function getAssetsDataForLtvCalculations(
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalanceCached
    ) external view returns (uint256,uint256,uint256) {
        ISiloConfig.ConfigData memory _collateralConfig = collateralConfig;
        ISiloConfig.ConfigData memory _debtConfig = debtConfig;
    
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _borrower,
            _oracleType,
            _accrueInMemory,
            _debtShareBalanceCached
        );
        return (
            ltvData.borrowerProtectedAssets,
            ltvData.borrowerCollateralAssets,
            ltvData.borrowerDebtAssets
        );
    }
}
