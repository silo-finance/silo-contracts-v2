// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

interface ISiloVaultDeployer {
    struct CreateSiloVaultParams {
        address initialOwner;
        uint256 initialTimelock;
        address asset;
        string name;
        string symbol;
        ISilo[] silosWithIncentives;
    }

    error EmptySiloVaultFactory();
    error EmptyIdleVaultFactory();
    error EmptySiloIncentivesControllerFactory();
    error EmptySiloIncentivesControllerCLFactory();
    error VaultAddressMismatch();
    error GaugeIsNotConfigured(address silo);

    function createSiloVault(CreateSiloVaultParams memory params) external returns (
        ISiloVault vault,
        ISiloIncentivesController incentivesController
    );
}