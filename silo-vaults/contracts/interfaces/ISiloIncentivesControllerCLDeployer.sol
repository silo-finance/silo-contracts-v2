// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {ISiloIncentivesControllerCLFactory} from "silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLFactory.sol";
import {SiloIncentivesControllerCL} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCL.sol";

/// @title ISiloIncentivesControllerCLDeployer
interface ISiloIncentivesControllerCLDeployer {
    /// @dev reverts in constructor if an address for ISiloIncentivesControllerCLFactory does not pass interface
    /// sanity check.
    error InvalidCLFactory();

    /// @dev reverts in resolveSiloVaultIncentivesController if SiloVault has more than one SiloIncentivesController.
    error MoreThanOneSiloVaultIncentivesController();

    /// @dev reverts in createIncentivesControllerCL if SiloVault's underlying market does not have configured
    /// incentives to claim rewards from.
    error UnderlyingMarketDoesNotHaveIncentives();

    /// @notice Creates a new SiloIncentivesControllerCL instance for a SiloVault. CL contract claims incentives from
    /// underlying market's incentives controller and distributes these incentives across depositors of the SiloVault.
    /// Deployed CL supports only SiloIncentivesController implementation to claim borrowable deposits incentives from
    /// Silo markets. CL address can be used to submitIncentivesClaimingLogic() and acceptIncentivesClaimingLogic() in
    /// VaultIncentivesModule.
    /// @dev Msg.sender address is used as an external sault for SiloIncentivesControllerCLFactory. Msg.sender must be
    /// an EOA or multisig.
    /// @dev This function must revert if SiloVault has more than one SiloIncentivesControllers in notification
    /// receivers. In this case the deployment of CL must be executed manually using SiloIncentivesControllerCLFactory
    /// with correct SiloVault's incentives controller.
    /// @param _siloVault SiloVault address.
    /// @param _market SiloVault's underlying market to claim incentives from.
    function createIncentivesControllerCL(
        address _siloVault,
        address _market
    ) external returns (SiloIncentivesControllerCL logic);

    /// @notice Returns an address of SiloIncentivesControllerCLFactory used to deploy SiloIncentivesControllerCL.
    /// The factory stored as an immutable variable.
    /// @return clFactory CL factory address.
    function siloIncentivesControllerCLFactory() external view returns (ISiloIncentivesControllerCLFactory clFactory);

    /// @notice get SiloVault's SiloIncentivesController from VaultIncentivesModule. This function reverts if SiloVault
    /// has more than one controller.
    /// @param _siloVault SiloVault address.
    /// @return controller SiloIncentivesController.
    function resolveSiloVaultIncentivesController(address _siloVault)
        external
        view
        returns (ISiloIncentivesController controller);
    
    /// @notice get underlying market's SiloIncentivesController.
    /// @param _market SiloVault's underlying market address.
    /// @return controller underlying market address.
    function resolveMarketIncentivesController(address _market)
        external
        view
        returns (ISiloIncentivesController controller);
}
