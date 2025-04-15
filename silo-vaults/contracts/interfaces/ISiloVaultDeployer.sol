// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

interface ISiloVaultDeployer {
    error EmptySiloVaultFactory();
    error EmptyIdleVaultFactory();
    error EmptySiloIncentivesControllerFactory();
    error EmptySiloIncentivesControllerCLFactory();
    error VaultAddressMismatch();

    function createSiloVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol
    ) external returns (
        ISiloVault vault,
        ISiloIncentivesController incentivesController
    );
}