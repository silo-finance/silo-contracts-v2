// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {
    ISiloIncentivesController,
    IDistributionManager
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

import {IIncentivesClaimingLogic} from "../../interfaces/IIncentivesClaimingLogic.sol";

contract SiloIncentivesControllerCL is IIncentivesClaimingLogic {
    ISiloIncentivesController public immutable VAULT_INCENTIVES_CONTROLLER;
    ISiloIncentivesController public immutable SILO_INCENTIVES_CONTROLLER;

    constructor(
        address _vaultIncentivesController,
        address _siloIncentivesController
    ) {
        VAULT_INCENTIVES_CONTROLLER = ISiloIncentivesController(_vaultIncentivesController);
        SILO_INCENTIVES_CONTROLLER = ISiloIncentivesController(_siloIncentivesController);
    }

    function claimRewardsAndDistribute() external virtual {
        IDistributionManager.AccruedRewards[] memory accruedRewards =
            SILO_INCENTIVES_CONTROLLER.claimRewards(address(VAULT_INCENTIVES_CONTROLLER));

        for (uint256 i = 0; i < accruedRewards.length; i++) {
            if (accruedRewards[i].amount == 0) continue;

            VAULT_INCENTIVES_CONTROLLER.immediateDistribution(
                accruedRewards[i].rewardToken,
                uint104(accruedRewards[i].amount)
            );
        }
    }
}
