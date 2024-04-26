// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloLens} from "../interfaces/ISiloLens.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {ConfigLib} from "./ConfigLib.sol";
import {Hook} from "./Hook.sol";

library SiloLensLib {
    function borrowPossible(ISilo _silo, address _borrower) internal view returns (bool possible) {
        (
            ,, ISiloConfig.DebtInfo memory debtInfo
        ) = ConfigLib.pullConfigs(_silo.config(), address(_silo), _borrower, Hook.BORROW);

        possible = SiloLendingLib.borrowPossible(debtInfo);
    }

    function getMaxLtv(ISilo _silo) internal view returns (uint256 maxLtv) {
        maxLtv = _silo.config().getConfig(address(_silo)).maxLtv;
    }

    function getLt(ISilo _silo) internal view returns (uint256 lt) {
        lt = _silo.config().getConfig(address(_silo)).lt;
    }

    function getLtv(ISilo _silo, address _borrower) internal view returns (uint256 ltv) {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
        ) = ConfigLib.pullConfigs(_silo.config(), address(_silo), _borrower, Hook.NONE);

        ltv = SiloSolvencyLib.getLtv(
            collateralConfig,
            debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            IShareToken(debtConfig.debtShareToken).balanceOf(_borrower)
        );
    }
}
