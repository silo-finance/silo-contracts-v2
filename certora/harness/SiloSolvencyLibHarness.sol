// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SiloSolvencyLib, ISiloConfig, ISilo} from "silo-core/contracts/lib/SiloSolvencyLib.sol";

contract SiloSolvencyLibHarness {

    function isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 debtShareBalance
    ) external view returns (bool) {
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
}