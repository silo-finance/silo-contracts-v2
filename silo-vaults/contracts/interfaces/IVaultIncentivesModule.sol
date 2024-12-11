// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IIncentivesClaimingLogic} from "./IIncentivesClaimingLogic.sol";
import {IIncentivesDistributionSolution} from "./IIncentivesDistributionSolution.sol";

/// @title Vault Incentives Module interface
interface IVaultIncentivesModule {
    event IncentivesClaimingLogicAdded(address logic);
    event IncentivesClaimingLogicRemoved(address logic);
    event IncentivesDistributionSolutionAdded(address solution);
    event IncentivesDistributionSolutionRemoved(address solution);

    error AddressZero();
    error LogicAlreadyAdded();
    error LogicNotFound();
    error SolutionAlreadyAdded();
    error SolutionNotFound();

    /// @notice Add an incentives claiming logic for the vault.
    /// @param logic The logic to add.
    function addIncentivesClaimingLogic(IIncentivesClaimingLogic logic) external;

    /// @notice Remove an incentives claiming logic for the vault.
    /// @param logic The logic to remove.
    function removeIncentivesClaimingLogic(IIncentivesClaimingLogic logic) external;

    /// @notice Add an incentives distribution solution for the vault.
    /// @param solution The solution to add.
    function addIncentivesDistributionSolution(IIncentivesDistributionSolution solution) external;

    /// @notice Remove an incentives distribution solution for the vault.
    /// @param solution The solution to remove.
    function removeIncentivesDistributionSolution(IIncentivesDistributionSolution solution) external;

    /// @notice Get all incentives claiming logics for the vault.
    /// @return logics The logics.
    function getIncentivesClaimingLogics() external view returns (address[] memory logics);

    /// @notice Get all incentives distribution solutions for the vault.
    /// @return solutions The solutions.
    function getIncentivesDistributionSolutions() external view returns (address[] memory solutions);
}
