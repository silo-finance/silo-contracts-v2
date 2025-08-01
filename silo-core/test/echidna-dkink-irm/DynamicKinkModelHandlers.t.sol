// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DynamicKinkModel} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Setup} from "silo-core/test/echidna-dkink-irm/base/Setup.t.sol";

/// @title DynamicKinkModelHandlers
abstract contract DynamicKinkModelHandlers is Setup {
    /// @notice Updates the setup of the IRM
    /// @param config The config to create the IRM if not created yet or update the IRM with
    /// @param _k The k value to update the IRM with
    function updateSetup(IDynamicKinkModel.Config memory config, int256 _k) public {
        config.ulow = config.ulow % _DP_WITH_ERROR;
        config.u1 = config.u1 % _DP_WITH_ERROR;
        config.u2 = config.u2 % _DP_WITH_ERROR;
        config.ucrit = config.ucrit % _DP_WITH_ERROR;
        config.rmin = config.rmin % _DP_WITH_ERROR;
        config.kmin = config.kmin % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.kmax = config.kmax % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.alpha = config.alpha % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.cminus = config.cminus % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.cplus = config.cplus % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.c1 = config.c1 % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.c2 = config.c2 % _UNIVERSAL_LIMIT_WITH_ERROR;
        config.dmax = config.dmax % _UNIVERSAL_LIMIT_WITH_ERROR;

        _updateStateBefore();
        DynamicKinkModel(address(_irm)).updateSetup(ISilo(address(_siloMock)), config, _k);
        _updateStateAfter();
    }

    /// @notice Modifier to set up Silo state with bounds
    /// @param _collateralAssets The collateral assets amount
    /// @param _debtAssets The debt assets amount
    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets
    ) public returns (uint256, uint256) {
        _updateStateBefore();

        _siloMock.setUtilizationData(
            _collateralAssets,
            _debtAssets,
            uint64(block.timestamp)
        );

        _updateStateAfter();

        return (_collateralAssets, _debtAssets);
    }
}
