// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IPendleMarketLike} from "silo-core/contracts/interfaces/IPendleMarketLike.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

interface IPendleRewardsClaimer is IHookReceiver {
    event FailedToClaimIncentives(address _silo);
    event ConfigUpdated(IPendleMarketLike _pendleMarket, ISiloIncentivesController _incentivesController);

    error WrongPendleMarket();
    error EmptyAddress();
    error OnlyHookReceiver();
    error MissingConfiguration();
    error WrongIncentivesControllerNotifier();
    error WrongIncentivesControllerShareToken();
    error CollateralDepositNotAllowed();

    /// @notice Redeem rewards from Pendle
    /// @return rewardTokens Reward tokens
    /// @return rewards Rewards for collateral token
    function redeemRewards() external returns (address[] memory rewardTokens, uint256[] memory rewards);

    /// @notice Set the config for the hook receiver
    /// @param _pendleMarket Pendle market address
    /// @param _incentivesController Incentives controller address for the protected share token
    function setConfig(IPendleMarketLike _pendleMarket, ISiloIncentivesController _incentivesController) external;
}
