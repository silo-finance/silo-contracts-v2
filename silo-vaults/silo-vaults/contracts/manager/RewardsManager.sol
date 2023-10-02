// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {
    ERC4626Upgradeable,
    ERC20Upgradeable,
    IERC20Upgradeable as IERC20,
    IERC20MetadataUpgradeable as IERC20Metadata
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {IBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerMinter.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RewardsManager is Ownable {
    using SafeERC20 for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    using Math for uint256;

    struct RewardInfo {
        uint256 index;
        uint8 decimals;
        ISiloLiquidityGauge gauge;
    }
    /// Errors
    error RewardTokenAlreadyAdded(IERC20 rewardToken);

    /// Events
    event RewardsClaimed(address indexed user, IERC20 rewardToken, uint256 amount);

    /// Rewards
    IERC20[] public rewardTokens;
    mapping(IERC20 => RewardInfo) public rewardInfos;
    mapping(address => mapping(IERC20 => uint256)) public accruedRewards;
    mapping(address => mapping(IERC20 => uint256)) internal userIndex;

    /*//////////////////////////////////////////////////////////////
                    REWARDS MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows owner to add a reward token to Meta Silo.
     * @dev Reward token must be an ERC20.
     * @param tokenAddress address of the reward token.
     * @param _gauge to claim reward tokens from.
     */
    function addRewardToken(address tokenAddress, address gauge) external onlyOwner {
        IERC20 rewardToken = IERC20(tokenAddress);
        rewardInfos[rewardToken] = RewardInfo({
            index: 0,
            decimals: IERC20Metadata(address(tokenAddress)).decimals(),
            gauge: _gauge
        });
        rewardTokens.push(rewardToken);
    }

    /*//////////////////////////////////////////////////////////////
                        REWARDS ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier accrueRewards(address _receiver) {
        IERC20[] memory _rewardTokens = rewardTokens;
        for (uint8 i; i < _rewardTokens.length; i++) {
            IERC20 rewardToken = _rewardTokens[i];
            RewardInfo memory rewards = rewardInfos[rewardToken];
            _accrueUser(_receiver, rewardToken);
        }
        _;
    }

    /**
     * @notice Syncs a user's accrued rewards to the latest global reward index
     * @dev Fetches the user's last synchronized index and calculates the delta to the current global index. 
     * Uses the delta and user's vault balance to increment their accrued rewards
     * @param _user The address of the user to sync accrued rewards for
     * @param _rewardToken The reward token to sync accrued rewards for
     */
    function _accrueUser(address _user, IERC20 _rewardToken) internal {
        RewardInfo memory rewards = rewardInfos[_rewardToken];

        /// Get user's index the last time their rewards were synced and calculate delta
        uint256 lastSyncedIndex = userIndex[_user][_rewardToken];
        uint256 deltaIndex = rewards.index - lastSyncedIndex;

        /// Calculate additional rewards user has accrued, based on urrent vault balance of user
        uint256 newEarnedRewards = (balanceOf(_user) * deltaIndex).mulDiv(10**rewards.decimals, 1e18);

        /// Update user's index to new global index and increment user's total accrued rewards
        userIndex[_user][_rewardToken] = rewards.index;
        accruedRewards[_user][_rewardToken] += newEarnedRewards;
    }

    /**
    * @notice Accrues global rewards for a reward token
    * @dev Increments the global reward index based on the amount of new rewards
    * @param _rewardToken The reward token to accrue rewards for 
    * @param accrued The amount of new rewards accrued
    */
    function _accrueRewards(IERC20 _rewardToken, uint256 _accrued) internal {
        RewardInfo storage rewards = rewardInfos[_rewardToken];

        /// Calculate increase in global index and increment; 
        if (_accrued != 0) {
            rewards.index += _accrued.mulDiv(10**rewards.decimals, 1e18);
        }  
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
    * @notice Claims accrued rewards for msg.sender
    * @dev Loops through all accrued reward tokens and transfers rewards owed to msg.sender
    */
    function claimRewards() external accrueRewards(msg.sender) {
        address user = msg.sender();
        for (uint8 i; i < _rewardTokens.length; i++) {
            uint256 rewardAmount = accruedRewards[user][_rewardTokens[i]];
            if (rewardAmount == 0) continue; /// here we don't want to revert if there is no reward
            accruedRewards[user][_rewardTokens[i]] = 0;
            _rewardTokens[i].transfer(user, rewardAmount);
            emit RewardsClaimed(user, _rewardTokens[i], rewardAmount);
        }
    }
}
