// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

/// @title Stream
/// @notice This contract allows the owner to set a beneficiary and stream tokens to them at a specified rate.
contract Stream is Ownable2Step {
    using SafeERC20 for IERC20;

    error DistributionTimeExpired();
    error NoBalance();

    event BeneficiaryUpdated(address indexed beneficiary);
    event RewardTokenUpdated(address indexed rewardToken);
    event EmissionsUpdated(uint256 indexed emissionPerSecond, uint256 indexed distributionEnd);
    event RewardsClaimed(address indexed beneficiary, uint256 indexed amount);

    /// @notice address that can claim rewards
    address public beneficiary;

    /// @notice token in which rewards are distributed
    address public rewardToken;

    /// @notice amount of rewards distributed per second
    uint256 public emissionPerSecond;

    /// @notice timestamp when distribution ends
    uint256 public distributionEnd;

    /// @notice timestamp of the last update
    uint256 public lastUpdateTimestamp;

    constructor(address _initialOwner, address _beneficiary, address _rewardToken) Ownable(_initialOwner) {
        beneficiary = _beneficiary;
        rewardToken = _rewardToken;
        distributionEnd = block.timestamp;
        lastUpdateTimestamp = block.timestamp;
    }

    /// @notice Calculate the funding gap for the stream.
    /// @return gap The amount of tokens needed to fund the stream.
    function fundingGap() public view returns (uint256 gap) {
        if (lastUpdateTimestamp >= distributionEnd) return 0;

        uint256 timeElapsed = distributionEnd - lastUpdateTimestamp;
        uint256 rewards = timeElapsed * emissionPerSecond;
        uint256 balanceOf = IERC20(rewardToken).balanceOf(address(this));

        gap = balanceOf >= rewards ? 0 : rewards - balanceOf;
    }

    /// @notice Calculate the pending rewards for the beneficiary.
    /// @return rewards The amount of pending rewards.
    function pendingRewards() public view returns (uint256 rewards) {
        if (lastUpdateTimestamp > distributionEnd) return 0;

        uint256 timeElapsed = Math.min(block.timestamp, distributionEnd) - lastUpdateTimestamp;
        rewards = timeElapsed * emissionPerSecond;
    }

    function claimRewards() public returns (uint256 rewards) {
        rewards = pendingRewards();
        uint256 balanceOf = IERC20(rewardToken).balanceOf(address(this));

        if (rewards > 0 && balanceOf >= rewards) {
            lastUpdateTimestamp = block.timestamp;
            IERC20(rewardToken).safeTransfer(beneficiary, rewards);
            emit RewardsClaimed(beneficiary, rewards);
        }
    }

    ///////////////////////
    /// OWNER FUNCTIONS ///
    ///////////////////////

    /// @notice Set the beneficiary address.
    /// @param _beneficiary The new beneficiary address.
    /// @dev Only the contract owner can call this function.
    function setBeneficiary(address _beneficiary) external onlyOwner {
        beneficiary = _beneficiary;

        emit BeneficiaryUpdated(_beneficiary);
    }

    /// @notice Set the reward token address.
    /// @param _rewardToken The new reward token address.
    /// @dev Only the contract owner can call this function.
    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;

        emit RewardTokenUpdated(_rewardToken);
    }

    /// @notice Set the emission rate and distribution end timestamp.
    /// @param _emissionPerSecond The new emission rate.
    /// @param _distributionEnd The new distribution end timestamp.
    /// @dev Only the contract owner can call this function.
    /// @dev The distribution end timestamp must be in the future.
    function setEmissions(uint256 _emissionPerSecond, uint256 _distributionEnd) external onlyOwner {
        require(_distributionEnd > block.timestamp, DistributionTimeExpired());

        emissionPerSecond = _emissionPerSecond;
        distributionEnd = _distributionEnd;

        emit EmissionsUpdated(_emissionPerSecond, _distributionEnd);
    }

    /// @dev Emergency withdraw token's balance on the contract
    function emergencyWithdraw(IERC20 _token) public onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        require(balance != 0, NoBalance());

        _token.safeTransfer(msg.sender, balance);
    }
}
