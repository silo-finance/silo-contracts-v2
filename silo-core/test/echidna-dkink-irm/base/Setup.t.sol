// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Hooks} from "silo-core/test/echidna-dkink-irm/base/Hooks.t.sol";
import {DynamicKinkModelFactory} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelFactory} from "silo-core/contracts/interfaces/IDynamicKinkModelFactory.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloDKinkMock} from "silo-core/test/echidna-dkink-irm/mocks/SiloDKinkMock.sol";

/// @title Setup
/// @notice Deployment and initialization logic for DynamicKinkModel testing
/// @dev Handles contract deployment and initial configuration
abstract contract Setup is Hooks {
    /// @notice Deploy factory and IRM with given configuration
    /// @return deployedIrm The deployed IRM instance
    function _deployDynamicKinkModel() internal virtual returns (IDynamicKinkModel) {
        // Deploy factory if not already deployed
        if (address(_factory) == address(0)) {
            _factory = new DynamicKinkModelFactory();
        }

        if (address(_irm) != address(0)) {
            return _irm;
        }

        // We start from the empty state
        IDynamicKinkModel.Config memory config = IDynamicKinkModel.Config({
            ulow: 0,
            u1: 0,
            u2: 0,
            ucrit: 0,
            rmin: 0,
            kmin: 0,
            kmax: 0,
            alpha: 0,
            cminus: 0,
            cplus: 0,
            c1: 0,
            c2: 0,
            dmax: 0
        });

        (, IInterestRateModel deployed) = _factory.create({
            _config: config,
            _initialOwner: address(this)
        });

        _irm = IDynamicKinkModel(address(deployed));

        return _irm;
    }

    /// @notice Deploy Silo mock
    function _deploySiloMock() internal virtual returns (SiloDKinkMock) {
        if (address(_siloMock) != address(0)) return _siloMock;

        _siloMock = new SiloDKinkMock(_irm);

        return _siloMock;
    }
}
