// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SiloSolvencyLib, ISiloConfig, ISilo} from "silo-core/contracts/lib/SiloSolvencyLib.sol";

contract SiloSolvencyLibHarness {

    ISiloConfig.ConfigData internal collateralConfig;
    ISiloConfig.ConfigData internal debtConfig;

    function isSolvent(
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 debtShareBalance
    ) external view returns (bool) {
        ISiloConfig.ConfigData memory _collateralConfig = collateralConfig;
        ISiloConfig.ConfigData memory _debtConfig = debtConfig;
        
        return SiloSolvencyLib.isSolvent
        (
            _collateralConfig,
            _debtConfig,
            _borrower,
            _accrueInMemory,
            debtShareBalance
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
    ) external view returns (SiloSolvencyLib.LtvData memory ltvData) {
        ISiloConfig.ConfigData memory _collateralConfig = collateralConfig;
        ISiloConfig.ConfigData memory _debtConfig = debtConfig;
    
        return SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _borrower,
            _oracleType,
            _accrueInMemory,
            _debtShareBalanceCached
        );
    }
}