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
    using SiloLensLib for ISilo;

    /// @inheritdoc ISiloLens
    function depositPossible(ISilo _silo, address _depositor) external view virtual returns (bool) {
        return _silo.depositPossible(_depositor);
    }

    /// @inheritdoc ISiloLens
    function borrowPossible(ISilo _silo, address _borrower) external view virtual returns (bool) {
        return _silo.borrowPossible(_borrower);
    }

    /// @inheritdoc ISiloLens
    function getMaxLtv(ISilo _silo) external view virtual returns (uint256 maxLtv) {
        return _silo.getMaxLtv();
    }

    /// @inheritdoc ISiloLens
    function getLt(ISilo _silo) external view virtual returns (uint256 lt) {
        return _silo.getLt();
    }

    /// @inheritdoc ISiloLens
    function getLtv(ISilo _silo, address _borrower) external view virtual returns (uint256 ltv) {
        return _silo.getLtv(_borrower);
    }
}
