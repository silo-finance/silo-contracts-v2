// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {IVaultIncentivesModule} from "../interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesDistributionSolution} from "../interfaces/IIncentivesDistributionSolution.sol";

/// @title Vault Incentives Module
contract VaultIncentivesModule is IVaultIncentivesModule, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _logics;
    EnumerableSet.AddressSet private _solutions;

    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesClaimingLogic(IIncentivesClaimingLogic logic) external onlyOwner {
        require(address(logic) != address(0), AddressZero());
        require(_logics.add(address(logic)), LogicAlreadyAdded());

        emit IncentivesClaimingLogicAdded(address(logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(IIncentivesClaimingLogic logic) external onlyOwner {
        require(_logics.remove(address(logic)), LogicNotFound());

        emit IncentivesClaimingLogicRemoved(address(logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesDistributionSolution(IIncentivesDistributionSolution solution) external onlyOwner {
        require(address(solution) != address(0), AddressZero());
        require(_solutions.add(address(solution)), SolutionAlreadyAdded());

        emit IncentivesDistributionSolutionAdded(address(solution));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesDistributionSolution(IIncentivesDistributionSolution solution) external onlyOwner {
        require(_solutions.remove(address(solution)), SolutionNotFound());

        emit IncentivesDistributionSolutionRemoved(address(solution));
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesClaimingLogics() external view returns (address[] memory logics) {
        logics = _logics.values();
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesDistributionSolutions() external view returns (address[] memory solutions) {
        solutions = _solutions.values();
    }
}
