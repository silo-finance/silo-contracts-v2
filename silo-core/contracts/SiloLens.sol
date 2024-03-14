// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloLens, ISilo} from "./interfaces/ISiloLens.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

import {SiloLensLib} from "./lib/SiloLensLib.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";


/// @title SiloLens has some helper methods that can be useful with integration
contract SiloLens is ISiloLens {
    using SiloLensLib for ISilo;

    /// @inheritdoc ISiloLens
    function depositPossible(ISilo _silo, address _depositor) external view virtual returns (bool) {
        return _silo.depositPossible(_depositor);
    }

    /// @inheritdoc ISiloLens
    function borrowPossible(ISilo _silo, address _borrower) external view virtual returns (bool possible) {
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

    /// @inheritdoc ISiloLens
    function getFeesAndFeeReceivers(ISilo _silo)
        external
        view
        virtual
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee)
    {
        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee,) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);
    }
}
