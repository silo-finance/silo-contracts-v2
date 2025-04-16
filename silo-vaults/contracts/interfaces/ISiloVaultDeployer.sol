// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IIncentivesClaimingLogicFactory} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogicFactory.sol";

/// @title ISiloVaultDeployer
/// @dev Deploys Silo Vault,Idle Vault, and Silo Incentives Controllers together with
/// initial configuration of the vault incentives module for the given markets in the single transaction.
interface ISiloVaultDeployer {
    struct CreateSiloVaultParams {
        address initialOwner; // initial owner of the vault
        uint256 initialTimelock; // initial timelock of the vault
        address asset; // asset of the vault
        address incentivesControllerOwner; // owner of the incentives controller
        string name; // name of the vault
        string symbol; // symbol of the vault
        IIncentivesClaimingLogicFactory[] trustedFactories; // trusted factories for initial configuration
        ISilo[] silosWithIncentives; // silos with incentives for initial configuration
        // if `silosWithIncentives` empty initial configuration will be skipped
    }

    error EmptySiloVaultFactory();
    error EmptyIdleVaultFactory();
    error EmptySiloIncentivesControllerFactory();
    error EmptySiloIncentivesControllerCLFactory();
    error VaultAddressMismatch();
    error GaugeIsNotConfigured(address silo);

    /// @notice Emitted when a new Silo Vault is created.
    /// @param vault The address of the deployed Silo Vault.
    /// @param incentivesController The address of the deployed Silo Incentives Controller.
    /// @param idleVault The address of the deployed Idle Vault.
    event CreateSiloVault(address indexed vault, address incentivesController, address idleVault);

    /// @notice Emitted when a new Incentives Claiming Logic is created.
    /// @param vault The address of the deployed Silo Vault.
    /// @param market The address of the market.
    /// @param claimingLogic The address of the deployed Incentives Claiming Logic.
    event CreateIncentivesCL(address indexed vault, address market, address claimingLogic);

    /// @notice Create a new Silo Vault and incentives controller for the vault.
    /// Performs initial configuration of the vault incentives module for the given markets.
    /// @param params The parameters for the Silo Vault deployment.
    /// @return vault The deployed Silo Vault.
    /// @return incentivesController The deployed Silo Incentives Controller.
    /// @return idleVault The deployed Idle Vault.
    function createSiloVault(CreateSiloVaultParams memory params) external returns (
        ISiloVault vault,
        ISiloIncentivesController incentivesController,
        IERC4626 idleVault
    );
}
