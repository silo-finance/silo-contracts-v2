// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

/// @title Stream
/// @notice This contract allows the owner to set a beneficiary and stream tokens to them at a specified rate.
contract Stream is Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice address that can claim rewards
    address public immutable BENEFICIARY;

    /// @notice token in which rewards are distributed
    address public immutable REWARD_ASSET;

    /// @notice amount of rewards distributed per second
    uint256 public emissionPerSecond;

    /// @notice timestamp when distribution ends
    uint256 public distributionEnd;

    /// @notice timestamp of the last update
    uint256 public lastUpdateTimestamp;

    event EmissionsUpdated(uint256 indexed emissionPerSecond, uint256 indexed distributionEnd);
    event RewardsClaimed(uint256 indexed amount);

    error DistributionTimeExpired();
    error NoBalance();

    constructor(address _initialOwner, address _beneficiary) Ownable(_initialOwner) {
        BENEFICIARY = _beneficiary;
        REWARD_ASSET = IERC4626(_beneficiary).asset();
        distributionEnd = block.timestamp;
        lastUpdateTimestamp = block.timestamp;
    }

    /// @notice Set the emission rate and distribution end timestamp.
    /// WARNING: do not set emissions fof xSilo when xSilo is empty or total supply is low:
    /// - it can break ratio.
    /// - it will lock dust balances.
    /// @param _emissionPerSecond The new emission rate.
    /// @param _distributionEnd The new distribution end timestamp.
    /// @dev Only the contract owner can call this function.
    /// @dev The distribution end timestamp must be in the future.
    function setEmissions(uint256 _emissionPerSecond, uint256 _distributionEnd) external onlyOwner {
        require(_distributionEnd > block.timestamp, DistributionTimeExpired());

        emissionPerSecond = _emissionPerSecond;
        distributionEnd = _distributionEnd;
        lastUpdateTimestamp = block.timestamp;

        emit EmissionsUpdated(_emissionPerSecond, _distributionEnd);
    }

    function claimRewards() public returns (uint256 rewards) {
        rewards = pendingRewards();
        lastUpdateTimestamp = block.timestamp;

        if (rewards != 0) {
            IERC20(REWARD_ASSET).safeTransfer(BENEFICIARY, rewards);
            emit RewardsClaimed(rewards);
        }
    }

    /// @dev Emergency withdraw token's balance on the contract
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = IERC20(REWARD_ASSET).balanceOf(address(this));
        require(balance != 0, NoBalance());

        IERC20(REWARD_ASSET).safeTransfer(msg.sender, balance);
    }

    /// @notice Calculate the funding gap for the stream.
    /// @return gap The amount of tokens needed to fund the stream.
    function fundingGap() public view returns (uint256 gap) {
        if (lastUpdateTimestamp >= distributionEnd) return 0;

        uint256 timeElapsed = distributionEnd - lastUpdateTimestamp;
        uint256 rewards = timeElapsed * emissionPerSecond;
        uint256 balanceOf = IERC20(REWARD_ASSET).balanceOf(address(this));

        gap = balanceOf >= rewards ? 0 : rewards - balanceOf;
    }

    /// @notice Calculate the pending rewards for the `BENEFICIARY`.
    /// @return rewards The amount of pending rewards.
    function pendingRewards() public view returns (uint256 rewards) {
        if (lastUpdateTimestamp >= distributionEnd) return 0;

        uint256 timeElapsed = Math.min(block.timestamp, distributionEnd) - lastUpdateTimestamp;
        uint256 balanceOf = IERC20(REWARD_ASSET).balanceOf(address(this));

        rewards = Math.min(timeElapsed * emissionPerSecond, balanceOf);
    }
}
