// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IIncentivesClaimingLogic} from "./IIncentivesClaimingLogic.sol";
import {IIncentivesDistributionSolution} from "./IIncentivesDistributionSolution.sol";

/// @title Vault Incentives Module interface
interface IVaultIncentivesModule {
    event IncentivesClaimingLogicAdded(address indexed market, address logic);
    event IncentivesClaimingLogicUpdated(address indexed market, address logic);
    event IncentivesClaimingLogicRemoved(address indexed market);
    event IncentivesDistributionSolutionAdded(address solution);
    event IncentivesDistributionSolutionRemoved(address solution);

    error AddressZero();
    error LogicAlreadyAdded();
    error LogicNotFound();
    error SolutionAlreadyAdded();
    error SolutionNotFound();
    error MarketAlreadySet();
    error MarketNotConfigured();

    /// @notice Add an incentives claiming logic for the vault.
    /// @param logic The logic to add.
    /// @param _market The market to add the logic for.
    function addIncentivesClaimingLogic(IIncentivesClaimingLogic logic, address _market) external;

    /// @notice Update an incentives claiming logic for the vault.
    /// @param logic The logic to update.
    /// @param _market The market to update the logic for.
    function updateIncentivesClaimingLogic(IIncentivesClaimingLogic logic, address _market) external;

    /// @notice Remove an incentives claiming logic for the vault.
    /// @param _market The market to remove the logic for.
    function removeIncentivesClaimingLogic(address _market) external;

    /// @notice Add an incentives distribution solution for the vault.
    /// @param solution The solution to add.
    function addIncentivesDistributionSolution(IIncentivesDistributionSolution solution) external;

    /// @notice Remove an incentives distribution solution for the vault.
    /// @param solution The solution to remove.
    function removeIncentivesDistributionSolution(IIncentivesDistributionSolution solution) external;

    /// @notice Get all incentives claiming logics for the vault.
    /// @return logics The logics.
    function getIncentivesClaimingLogics() external view returns (address[] memory logics);

    /// @notice Get all incentives claiming logics for the vault.
    /// @param _markets The markets to get the incentives claiming logics for.
    /// @return logics The logics.
    function getIncentivesClaimingLogics(address[] memory _markets) external view returns (address[] memory logics);

    /// @notice Get all incentives distribution solutions for the vault.
    /// @return solutions The solutions.
    function getIncentivesDistributionSolutions() external view returns (address[] memory solutions);

    /// @notice Get the incentives claiming logic for a market.
    /// @param market The market to get the incentives claiming logic for.
    /// @return logic The logic.
    function marketToLogic(address market) external view returns (address logic);
}

