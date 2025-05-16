// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


/// @title Stream
/// @notice This contract allows the owner to set a beneficiary and stream tokens to them at a specified rate.
interface IStream {
    /// @notice address that can claim rewards
    function BENEFICIARY() external returns (address);

    /// @notice token in which rewards are distributed
    function REWARD_ASSET() external returns (address);

    /// @notice amount of rewards distributed per second
    function emissionPerSecond() external returns (uint256);

    /// @notice timestamp when distribution ends
    function distributionEnd() external returns (uint256);

    /// @notice timestamp of the last update
    function lastUpdateTimestamp() external returns (uint256);

    event EmissionsUpdated(uint256 indexed emissionPerSecond, uint256 indexed distributionEnd);
    event RewardsClaimed(uint256 indexed amount);

    error DistributionTimeExpired();
    error NoBalance();

    /// @notice Set the emission rate and distribution end timestamp.
    /// WARNING: do not set emissions fof xSilo when xSilo is empty or total supply is low:
    /// - it can break ratio.
    /// - it will lock dust balances.
    /// @param _emissionPerSecond The new emission rate.
    /// @param _distributionEnd The new distribution end timestamp.
    /// @dev Only the contract owner can call this function.
    /// @dev The distribution end timestamp must be in the future.
    function setEmissions(uint256 _emissionPerSecond, uint256 _distributionEnd) external;

    function claimRewards() external returns (uint256 rewards);

    /// @dev Emergency withdraw token's balance on the contract
    function emergencyWithdraw() external;

    /// @notice Calculate the funding gap for the stream.
    /// @return gap The amount of tokens needed to fund the stream.
    function fundingGap() external view returns (uint256 gap);

    /// @notice Calculate the pending rewards for the `BENEFICIARY`.
    /// @return rewards The amount of pending rewards.
    function pendingRewards() external view returns (uint256 rewards);
}
