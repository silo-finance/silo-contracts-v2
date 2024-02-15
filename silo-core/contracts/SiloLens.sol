// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloLens, ISilo} from "./interfaces/ISiloLens.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

import {SiloLensLib} from "./lib/SiloLensLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";


/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract SiloLens is ISiloLens {
    /// @inheritdoc ISiloLens
    function isSolvent(ISilo _silo, address _borrower) external view virtual returns (bool) {
        return SiloLensLib.isSolvent(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function depositPossible(ISilo _silo, address _depositor) external view virtual returns (bool) {
        return SiloLensLib.depositPossible(_silo, _depositor);
    }

    /// @inheritdoc ISiloLens
    function borrowPossible(ISilo _silo, address _borrower) external view virtual returns (bool) {
        return SiloLensLib.borrowPossible(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function getMaxLtv(ISilo _silo) external view virtual returns (uint256 maxLtv) {
        maxLtv = _silo.config().getConfig(address(_silo)).maxLtv;
    }

    /// @inheritdoc ISiloLens
    function getLt(ISilo _silo) external view virtual returns (uint256 lt) {
        lt = _silo.config().getConfig(address(_silo)).lt;
    }

    /// @inheritdoc ISiloLens
    function getLtv(ISilo _silo, address _borrower) external view virtual returns (uint256 ltv) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = SiloLensLib.getOrderedConfigs(_silo, _borrower);

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
