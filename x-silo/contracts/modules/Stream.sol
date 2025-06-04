// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IStream} from "../interfaces/IStream.sol";

/// @title Stream
/// @notice This contract allows the owner to set a beneficiary and stream tokens to them at a specified rate.
contract Stream is IStream, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @inheritdoc IStream
    address public immutable BENEFICIARY;

    /// @inheritdoc IStream
    address public immutable REWARD_ASSET;

    /// @inheritdoc IStream
    uint256 public emissionPerSecond;

    /// @inheritdoc IStream
    uint256 public distributionEnd;

    /// @inheritdoc IStream
    uint256 public lastUpdateTimestamp;

    constructor(address _initialOwner, address _beneficiary) Ownable(_initialOwner) {
        BENEFICIARY = _beneficiary;
        REWARD_ASSET = IERC4626(_beneficiary).asset();
        distributionEnd = block.timestamp;
        lastUpdateTimestamp = block.timestamp;
    }

    /// @inheritdoc IStream
    function setEmissions(uint256 _emissionPerSecond, uint256 _distributionEnd) external onlyOwner {
        claimRewards();

        if (_emissionPerSecond == 0) {
            _distributionEnd = block.timestamp;
        } else {
            require(_distributionEnd > block.timestamp, DistributionTimeExpired());
        }

        emissionPerSecond = _emissionPerSecond;
        distributionEnd = _distributionEnd;

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

    /// @inheritdoc IStream
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = IERC20(REWARD_ASSET).balanceOf(address(this));
        require(balance != 0, NoBalance());

        IERC20(REWARD_ASSET).safeTransfer(msg.sender, balance);
    }

    /// @inheritdoc IStream
    function fundingGap() public view returns (uint256 gap) {
        if (lastUpdateTimestamp >= distributionEnd) return 0;

        uint256 timeElapsed = distributionEnd - lastUpdateTimestamp;
        uint256 rewards = timeElapsed * emissionPerSecond;
        uint256 balanceOf = IERC20(REWARD_ASSET).balanceOf(address(this));

        gap = balanceOf >= rewards ? 0 : rewards - balanceOf;
    }

    /// @inheritdoc IStream
    function pendingRewards() public view returns (uint256 rewards) {
        uint256 lastUpdateTimestamp_ = lastUpdateTimestamp;
        uint256 distributionEnd_ = distributionEnd;

        if (lastUpdateTimestamp_ >= distributionEnd_) return 0;

        uint256 timeElapsed = Math.min(block.timestamp, distributionEnd_) - lastUpdateTimestamp_;
        uint256 balanceOf = IERC20(REWARD_ASSET).balanceOf(address(this));

        rewards = Math.min(timeElapsed * emissionPerSecond, balanceOf);
    }
}
