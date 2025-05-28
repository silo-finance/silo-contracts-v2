// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IPendleMarketLike} from "silo-core/contracts/interfaces/IPendleMarketLike.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

interface IPendleRewardsClaimer is IHookReceiver {
    event ConfigUpdated(
        IPendleMarketLike _pendleMarket,
        ISiloIncentivesController _incentivesControllerCollateral,
        ISiloIncentivesController _incentivesControllerProtected
    );

    event FailedToClaimIncentives(address _silo);

    error WrongPendleMarket();
    error EmptyAddress();
    error OnlyHookReceiver();
    error MissingConfiguration();
    error WrongCollateralIncentivesControllerNotifier();
    error WrongProtectedIncentivesControllerNotifier();
    error WrongCollateralIncentivesControllerShareToken();
    error WrongProtectedIncentivesControllerShareToken();

    /// @notice Redeem rewards from Pendle
    /// @return rewardTokens Reward tokens
    /// @return collateralRewards Rewards for collateral token
    /// @return protectedRewards Rewards for protected token
    function redeemRewards()
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory collateralRewards,
            uint256[] memory protectedRewards
        );

    /// @notice Set the config for the hook receiver
    /// @param _pendleMarket Pendle market address
    /// @param _incentivesControllerCollateral Incentives controller address for borrowable deposits
    /// @param _incentivesControllerProtected Incentives controller address for non borrowable deposits
    function setConfig(
        IPendleMarketLike _pendleMarket,
        ISiloIncentivesController _incentivesControllerCollateral,
        ISiloIncentivesController _incentivesControllerProtected
    ) external;
}
