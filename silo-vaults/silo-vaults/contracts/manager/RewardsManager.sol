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
        uint64 ONE;
        uint224 index;
        bool exists;
        ISiloLiquidityGauge gauge;
    }
    /// Errors
    error RewardTokenAlreadyAdded(IERC20 rewardToken);

    /// Events
    event RewardsClaimed(address indexed user, IERC20 rewardToken, uint256 amount);

    /// Rewards
    IERC20[] public rewardTokens;
    address public constant SILO = 0x6f80310ca7f2c654691d1383149fa1a57d8ab1f8;
    mapping(IERC20 => RewardInfo) public rewardInfos;
    mapping(address => mapping(IERC20 => uint256)) public accruedRewards;
    mapping(address => mapping(IERC20 => uint256)) internal userIndex;

    function __RewardManager_init(address _balancerMinter) internal {
        balancerMinter = IBalancerMinter(_balancerMinter);
    }

    /*//////////////////////////////////////////////////////////////
                    REWARDS MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows owner to add a reward token to Meta Silo.
     * @dev Reward token must be an ERC20.
     * @param tokenAddress address of the reward token.
     * @param _gauge to claim reward tokens from.
     */
    function addRewardToken(address tokenAddress, ISiloLiquidityGauge _gauge) external onlyOwner {
        IERC20 rewardToken = IERC20(tokenAddress);
        if (rewardInfos[rewardToken].exists) revert RewardTokenAlreadyAdded(rewardToken);
        uint64 ONE = (10 ** IERC20Metadata(address(rewardsToken)).decimals()).safeCastTo64();
        rewardInfos[rewardToken] = RewardInfo({ONE: ONE, index: ONE, exists: true, gauge: _gauge});
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
     * @notice Claims pending rewards and update accounting
     */
     //TODO here I changed the logic to harvest both SILO tokens AND rewards tokens
    function _harvestRewards() internal {
        /// @notice first we claim SILO rewards
        IERC20 siloReward = IERC20(SILO);
        uint256 siloBalanceBefore = siloReward.balanceOf(address(this));
        for (uint256 i = 0; i < silos.length; i++) {
            if (gauge[silos[i]] != address(0)) {
                balancerMinter.mintFor(gauge[silos[i]], address(this));
            }
        }
        _accrueRewards(siloReward, siloReward.balanceOf(address(this)) - siloBalanceBefore);
        
        /// @notice then we claim other rewards, if applicable
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 reward = rewardTokens[i];
            RewardInfo memory rewards = rewardInfos[reward];
            uint256 balanceBefore = reward.balanceOf(address(this));
            rewards.gauge.claim_rewards(address(this), address(this));
            _accrueRewards(reward, reward.balanceOf(address(this)) - balanceBefore);
        }
    }

    /**
     * @notice Accrue global rewards for a rewardToken
     */
    function _accrueRewards(IERC20 _rewardToken, uint256 accrued) internal {
        uint256 supplyTokens = _rewardToken.totalSupply();
        //TODO figure out where to get decimals from
        //uint decimals = _rewardToken.decimals();
        uint256 decimals = uint256(0);
        if (supplyTokens != 0) {
            uint224 deltaIndex =
                accrued.mulDiv(uint256(10 ** decimals), supplyTokens, Math.Rounding.Down).safeCastTo224();
            rewardInfos[_rewardToken].index += deltaIndex;
        }
    }

    /// @notice Sync a user's rewards for a rewardToken with the global reward index for that token
    function _accrueUser(address _user, IERC20 _rewardToken) internal {
        RewardInfo memory rewards = rewardInfos[_rewardToken];

        uint256 oldIndex = userIndex[_user][_rewardToken];

        // If user hasn't yet accrued rewards, grant rewards from the strategy beginning if they have a balance
        // Zero balances will have no effect other than syncing to global index
        uint256 deltaIndex = oldIndex == 0 //TODO used to be rewards.ONE. replace uint(0) with a proper value
            ? rewards.index - uint256(0)
            : rewards.index - oldIndex;

        //TODO figure out where to get decimals from
        //uint decimals = _rewardToken.decimals();
        uint256 decimals = uint256(0);

        // Accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
        uint256 supplierDelta =
            _rewardToken.balanceOf(_user).mulDiv(deltaIndex, uint256(10 ** decimals), Math.Rounding.Down);

        userIndex[_user][_rewardToken] = rewards.index;
        accruedRewards[_user][_rewardToken] += supplierDelta;
    }
}

/*//////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

/**
 * @notice Claim rewards for a user in any amount of rewardTokens.
 * @param user User for which rewards should be claimed.
 * @param _rewardTokens Array of rewardTokens for which rewards should be claimed.
 * @dev This function will revert if any of the rewardTokens have zero rewards accrued.
 */
 //TODO here we should have no input arg, and allow msg.sender to retrieve all rewards, SILO and OTHERS
function claimRewards(address user, IERC20[] memory _rewardTokens) external accrueRewards(msg.sender) {
    for (uint8 i; i < _rewardTokens.length; i++) {
        uint256 rewardAmount = accruedRewards[user][_rewardTokens[i]];
        if (rewardAmount == 0) continue; // here we don't want to revert if there is no reward
        accruedRewards[user][_rewardTokens[i]] = 0;
        _rewardTokens[i].transfer(user, rewardAmount);
        emit RewardsClaimed(user, _rewardTokens[i], rewardAmount);
    }
}
