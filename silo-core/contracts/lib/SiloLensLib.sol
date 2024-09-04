// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloLens} from "../interfaces/ISiloLens.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {AssetTypes} from "./AssetTypes.sol";
import {Hook} from "./Hook.sol";

library SiloLensLib {
    function getRawLiquidity(ISilo _silo) internal view returns (uint256 liquidity) {
        return SiloMathLib.liquidity(
            _silo.getTotalAssetsStorage(AssetTypes.COLLATERAL),
            _silo.getTotalAssetsStorage(AssetTypes.DEBT)
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
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _silo.config().getConfigs(_borrower);

        if (debtConfig.silo != address(0)) {
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
}
