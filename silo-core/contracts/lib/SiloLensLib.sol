// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloLens} from "../interfaces/ISiloLens.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";

library SiloLensLib {
    function depositPossible(ISilo _silo, address _depositor) internal view returns (bool) {
        address debtShareToken = _silo.config().getConfig(address(_silo)).debtShareToken;
        return SiloERC4626Lib.depositPossible(debtShareToken, _depositor);
    }

    function borrowPossible(ISilo _silo, address _borrower) internal view returns (bool possible) {
        (
            ISiloConfig.ConfigData memory thisSiloConfig, ISiloConfig.ConfigData memory otherSiloConfig
        ) = _silo.config().getConfigs(address(_silo));

        (possible,,) = SiloLendingLib.borrowPossible(
            thisSiloConfig.protectedShareToken,
            thisSiloConfig.collateralShareToken,
            otherSiloConfig.debtShareToken,
            _borrower
        );
    }

    function getMaxLtv(ISilo _silo) internal view returns (uint256 maxLtv) {
        maxLtv = _silo.config().getConfig(address(_silo)).maxLtv;
    }

    function getLt(ISilo _silo) internal view returns (uint256 lt) {
        lt = _silo.config().getConfig(address(_silo)).lt;
    }

    function getLtv(ISilo _silo, address _borrower) internal view returns (uint256 ltv) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = SiloSolvencyLib.getOrderedConfigs(_silo, _silo.config(), _borrower);

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
