// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Storage} from "silo-core/test/echidna-dkink-irm/base/Storage.t.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {IDynamicKinkModelConfig} from "silo-core/contracts/interfaces/IDynamicKinkModelConfig.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {DynamicKinkModel} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {SiloDKinkMock} from "silo-core/test/echidna-dkink-irm/mocks/SiloDKinkMock.sol";

/// @title BaseHooks
/// @notice Hook management for pre/post action checks
/// @dev Allows for modular testing with before/after hooks
abstract contract Hooks is Storage {
    /// @dev Update state before silo state is updated
    function _updateStateBefore() internal {
        _updateSiloStateBefore();

        if (address(_irm) == address(0))  return;

        IDynamicKinkModel.Setup memory setup = DynamicKinkModel(address(_irm)).getSetup(address(_siloMock));
        _stateBefore.config = setup.config;
        _stateBefore.k = setup.k;
        _stateBefore.u = setup.u;
        _stateBefore.initialized = setup.initialized;

        _stateBefore.rcur = IInterestRateModel(address(_irm)).getCurrentInterestRate(
            address(_siloMock),
            block.timestamp
        );

        _stateBefore.rcomp = IInterestRateModel(address(_irm)).getCompoundInterestRate(
            address(_siloMock),
            block.timestamp
        );
    }

    /// @dev Update state after silo state is updated
    function _updateStateAfter() internal {
        _updateSiloStateAfter();

        if (address(_irm) == address(0))  return;

        IDynamicKinkModel.Setup memory setup = DynamicKinkModel(address(_irm)).getSetup(address(_siloMock));
        _stateAfter.config = setup.config;
        _stateAfter.k = setup.k;
        _stateAfter.u = setup.u;
        _stateAfter.initialized = setup.initialized;

        _stateAfter.rcur = IInterestRateModel(address(_irm)).getCurrentInterestRate(
            address(_siloMock),
            block.timestamp
        );

        _stateAfter.rcomp = IInterestRateModel(address(_irm)).getCompoundInterestRate(
            address(_siloMock),
            block.timestamp
        );
    }

    /// @dev Update state before silo state is updated
    function _updateSiloStateBefore() internal {
        ISilo.UtilizationData memory utilizationData = _siloMock.utilizationData();

        _stateBefore.collateralAssets = utilizationData.collateralAssets;
        _stateBefore.debtAssets = utilizationData.debtAssets;
        _stateBefore.interestRateTimestamp = utilizationData.interestRateTimestamp;
        _stateBefore.blockTimestamp = block.timestamp;
    }

    /// @dev Update state after silo state is updated
    function _updateSiloStateAfter() internal {
        ISilo.UtilizationData memory utilizationData = _siloMock.utilizationData();

        _stateAfter.collateralAssets = utilizationData.collateralAssets;
        _stateAfter.debtAssets = utilizationData.debtAssets;
        _stateAfter.interestRateTimestamp = utilizationData.interestRateTimestamp;
        _stateAfter.blockTimestamp = block.timestamp;
    }
}
