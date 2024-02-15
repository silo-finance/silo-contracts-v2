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
    function isSolvent(ISilo _silo, address _borrower) external view returns (bool) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = getOrderedConfigs(_silo, _borrower);

        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(_borrower);

        return SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, _borrower, ISilo.AccrueInterestInMemory.Yes, debtShareBalance
        );

    }

    function depositPossible(ISilo _silo, address _depositor) internal view returns (bool) {
        address debtShareToken = _silo.config().getConfig(address(_silo)).debtShareToken;
        return SiloERC4626Lib.depositPossible(debtShareToken, _depositor);
    }

    function borrowPossible(ISilo _silo, address _borrower) internal view returns (bool) {
        ISiloConfig.ConfigData memory configData = _silo.config().getConfig(address(_silo));

        return SiloLendingLib.borrowPossible(
            configData.protectedShareToken, configData.collateralShareToken, _borrower
        );
    }

    function getOrderedConfigs(ISilo _silo, address _borrower)
        internal
        view
        returns (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig)
    {
        (collateralConfig, debtConfig) = _silo.config().getConfigs(address(_silo));

        if (!SiloSolvencyLib.validConfigOrder(collateralConfig.debtShareToken, debtConfig.debtShareToken, _borrower)) {
            (collateralConfig, debtConfig) = (debtConfig, collateralConfig);
        }
    }
}
