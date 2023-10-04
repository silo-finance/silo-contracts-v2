// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract RewardsManager is Ownable {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    
    struct RewardInfo {
        uint224 index;
        address gauge;
    }

    event RewardsClaimed(address indexed user, ERC20 rewardToken, uint256 amount);

    ERC20[] public rewardTokens;
    mapping(ERC20 => RewardInfo) public rewardInfos;
    mapping(address => mapping(ERC20 => uint256)) public accruedRewards;
    mapping(address => mapping(ERC20 => uint256)) internal _userIndex;

    function addRewardToken(ERC20 rewardToken, address _gauge) external onlyOwner {
        rewardTokens.push(rewardToken);
        rewardInfos[rewardToken] = RewardInfo({
            index: index,
            gauge: _gauge
        });
    }

    modifier accrueRewards(address _receiver) {
        ERC20[] memory _rewardTokens = rewardTokens;
        for (uint8 i; i < _rewardTokens.length; i++) {
            ERC20 rewardToken = _rewardTokens[i];
            RewardInfo memory rewards = rewardInfos[rewardToken];
            _accrueUser(_receiver, rewardToken);
        }
        _;
    }

    function _accrueUser(address _user, ERC20 _rewardToken) internal {
        RewardInfo memory rewards = rewardInfos[_rewardToken];
        uint256 oldIndex = _userIndex[_user][_rewardToken];

        if (oldIndex == 0) {
            oldIndex = rewards.base;
        }

        uint256 deltaIndex = rewards.index - oldIndex;
        uint256 supplierDelta = balanceOf(_user).mulDiv(deltaIndex, uint256(1e18));
        _userIndex[_user][_rewardToken] = rewards.index;
        accruedRewards[_user][_rewardToken] += supplierDelta;
    }

    function _accrueRewards(ERC20 _rewardToken, uint256 accrued) internal {
        uint256 supplyTokens = _rewardToken.totalSupply();
        uint256 decimals = rewardInfos[_rewardToken].base;
        
        if (supplyTokens != 0) {
            uint224 deltaIndex =
                accrued.mulDiv(uint256(10 ** decimals), supplyTokens).safeCastTo224();
            rewardInfos[_rewardToken].index += deltaIndex;
        }
    }

    function claimRewards() external accrueRewards(msg.sender) {
        address user = address(msg.sender);
        for (uint8 i; i < _rewardTokens.length; i++) {
            uint256 rewardAmount = accruedRewards[user][_rewardTokens[i]];
            if (rewardAmount == 0) continue;
            accruedRewards[user][_rewardTokens[i]] = 0;
            _rewardTokens[i].transfer(user, rewardAmount);
            emit RewardsClaimed(user, _rewardTokens[i], rewardAmount);
        }
    }
}