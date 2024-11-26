// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {IDistributionManager} from "../interfaces/IDistributionManager.sol";
import {DistributionTypes} from "../lib/DistributionTypes.sol";

/**
 * @title DistributionManager
 * @notice Accounting contract to manage multiple staking distributions
 */
contract DistributionManager is IDistributionManager, Ownable2Step {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    EnumerableSet.Bytes32Set internal _incentivesProgramIds;

    mapping(bytes32 => IncentivesProgram) public incentivesPrograms;

    address public immutable NOTIFIER; // solhint-disable-line var-name-mixedcase

    uint8 public constant PRECISION = 18;
    uint256 public constant TEN_POW_PRECISION = 10 ** PRECISION;


    modifier onlyNotifier() {
        if (msg.sender != NOTIFIER) revert OnlyNotifier();
        _;
    }

    constructor(address _owner, address _notifier) Ownable(_owner) {
        NOTIFIER = _notifier;
    }

    /// @inheritdoc IDistributionManager
    function setDistributionEnd(
        string calldata _incentivesProgram,
        uint40 _distributionEnd
    ) external onlyOwner {
        bytes32 incentivesProgramId = keccak256(abi.encodePacked(_incentivesProgram));
        incentivesPrograms[incentivesProgramId].distributionEnd = _distributionEnd;

        emit DistributionEndUpdated(incentivesProgramId, _distributionEnd);
    }

    /// @inheritdoc IDistributionManager
    function getDistributionEnd(string calldata _incentivesProgram) external view override returns (uint256) {
        bytes32 incentivesProgramId = keccak256(abi.encodePacked(_incentivesProgram));
        return incentivesPrograms[incentivesProgramId].distributionEnd;
    }

    /// @inheritdoc IDistributionManager
    function getUserData(address _user, string calldata _incentivesProgram) public view override returns (uint256) {
        bytes32 incentivesProgramId = keccak256(abi.encodePacked(_incentivesProgram));
        return incentivesPrograms[incentivesProgramId].users[_user];
    }

    /// @inheritdoc IDistributionManager
    function getIncentivesProgramData(string calldata _incentivesProgram)
        public
        view
        override
        returns (
            uint256 index,
            uint256 emissionPerSecond,
            uint256 lastUpdateTimestamp,
            uint256 distributionEnd
        )
    {
        bytes32 incentivesProgramId = keccak256(abi.encodePacked(_incentivesProgram));

        index = incentivesPrograms[incentivesProgramId].index;
        emissionPerSecond = incentivesPrograms[incentivesProgramId].emissionPerSecond;
        lastUpdateTimestamp = incentivesPrograms[incentivesProgramId].lastUpdateTimestamp;
        distributionEnd = incentivesPrograms[incentivesProgramId].distributionEnd;
    }

    /// @inheritdoc IDistributionManager
    function incentivesProgram(string calldata _incentivesProgram)
        external
        view
        returns (IncentiveProgramDetails memory details)
    {
        bytes32 incentivesProgramId = keccak256(abi.encodePacked(_incentivesProgram));
        details = IncentiveProgramDetails(
            incentivesPrograms[incentivesProgramId].index,
            incentivesPrograms[incentivesProgramId].rewardToken,
            incentivesPrograms[incentivesProgramId].emissionPerSecond,
            incentivesPrograms[incentivesProgramId].lastUpdateTimestamp,
            incentivesPrograms[incentivesProgramId].distributionEnd
        );
    }

    /**
     * @dev Updates the state of one distribution, mainly rewards index and timestamp
     * @param incentivesProgramId The id of the incentives program being updated
     * @param totalStaked Current total of staked assets for this distribution
     * @return The new distribution index
     */
    function _updateAssetStateInternal(
        bytes32 incentivesProgramId,
        uint256 totalStaked
    ) internal returns (uint256) {
        uint256 oldIndex = incentivesPrograms[incentivesProgramId].index;
        uint256 emissionPerSecond = incentivesPrograms[incentivesProgramId].emissionPerSecond;
        uint256 lastUpdateTimestamp = incentivesPrograms[incentivesProgramId].lastUpdateTimestamp;
        uint256 distributionEnd = incentivesPrograms[incentivesProgramId].distributionEnd;

        if (block.timestamp == lastUpdateTimestamp) {
            return oldIndex;
        }

        uint256 newIndex = _getIncentivesProgramIndex(
            oldIndex, emissionPerSecond, lastUpdateTimestamp, distributionEnd, totalStaked
        );

        if (newIndex != oldIndex) {
            incentivesPrograms[incentivesProgramId].index = newIndex;
            incentivesPrograms[incentivesProgramId].lastUpdateTimestamp = uint40(block.timestamp);
            emit IncentivesProgramIndexUpdated(incentivesProgramId, newIndex);
        } else {
            incentivesPrograms[incentivesProgramId].lastUpdateTimestamp = uint40(block.timestamp);
        }

        return newIndex;
    }

    /**
     * @dev Updates the state of an user in a distribution
     * @param incentivesProgramId The id of the incentives program being updated
     * @param user The user's address
     * @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
     * @param totalStaked Total tokens staked in the distribution
     * @return The accrued rewards for the user until the moment
     */
    function _updateUserAssetInternal(
        bytes32 incentivesProgramId,
        address user,
        uint256 stakedByUser,
        uint256 totalStaked
    ) internal returns (uint256) {
        uint256 userIndex = incentivesPrograms[incentivesProgramId].users[user];
        uint256 accruedRewards = 0;

        uint256 newIndex = _updateAssetStateInternal(incentivesProgramId, totalStaked);

        if (userIndex != newIndex) {
            if (stakedByUser != 0) {
                accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
            }

            incentivesPrograms[incentivesProgramId].users[user] = newIndex;
            emit UserIndexUpdated(user, incentivesProgramId, newIndex);
        }

        return accruedRewards;
    }

    /**
     * @dev Used by "frontend" stake contracts to update the data of an user when claiming rewards from there
     * @param _user The address of the user
     * @return accruedRewards The accrued rewards for the user until the moment
     */
    function _accrueRewards(address _user)
        internal
        returns (AccruedRewards[] memory accruedRewards)
    {
        uint256 length = _incentivesProgramIds.length();
        accruedRewards = new AccruedRewards[](length);

        (uint256 userStaked, uint256 totalStaked) = _getScaledUserBalanceAndSupply(_user);

        for (uint256 i = 0; i < length; i++) {
            bytes32 incentivesProgramId = _incentivesProgramIds.at(i);
            accruedRewards[i] = _accrueRewards(_user, incentivesProgramId, totalStaked, userStaked);
        }
    }

    function _accrueRewards(address _user, bytes32 _programId, uint256 _totalStaked, uint256 _userStaked)
        internal
        returns (AccruedRewards memory accruedRewards)
    {
        uint256 rewards = _updateUserAssetInternal(
            _programId,
            _user,
            _userStaked,
            _totalStaked
        );

        accruedRewards = AccruedRewards({
            amount: rewards,
            programId: _programId,
            rewardToken: incentivesPrograms[_programId].rewardToken
        });
    }

    /**
     * @dev Return the accrued rewards for an user over a list of distribution
     * @param programId The id of the incentives program being updated
     * @param user The address of the user
     * @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
     * @param totalStaked Total tokens staked in the distribution
     * @return accruedRewards The accrued rewards for the user until the moment
     */
    function _getUnclaimedRewards(bytes32 programId, address user, uint256 stakedByUser, uint256 totalStaked)
        internal
        view
        returns (uint256 accruedRewards)
    {
        uint256 userIndex = incentivesPrograms[programId].users[user];

        uint256 incentivesProgramIndex = _getIncentivesProgramIndex(
            incentivesPrograms[programId].index,
            incentivesPrograms[programId].emissionPerSecond,
            incentivesPrograms[programId].lastUpdateTimestamp,
            incentivesPrograms[programId].distributionEnd,
            totalStaked
        );

        accruedRewards = _getRewards(stakedByUser, incentivesProgramIndex, userIndex);
    }

    /**
     * @dev Internal function for the calculation of user's rewards on a distribution
     * @param principalUserBalance Amount staked by the user on a distribution
     * @param reserveIndex Current index of the distribution
     * @param userIndex Index stored for the user, representation his staking moment
     * @return rewards The rewards
     */
    function _getRewards(
        uint256 principalUserBalance,
        uint256 reserveIndex,
        uint256 userIndex
    ) internal pure returns (uint256 rewards) {
        rewards = principalUserBalance * (reserveIndex - userIndex);
        unchecked { rewards /= TEN_POW_PRECISION; }
    }

    /**
     * @dev Calculates the next value of an specific distribution index, with validations
     * @param currentIndex Current index of the distribution
     * @param emissionPerSecond Representing the total rewards distributed per second per asset unit,
     * on the distribution
     * @param lastUpdateTimestamp Last moment this distribution was updated
     * @param distributionEnd The end of the distribution
     * @param totalBalance of tokens considered for the distribution
     * @return newIndex The new index.
     */
    function _getIncentivesProgramIndex(
        uint256 currentIndex,
        uint256 emissionPerSecond,
        uint256 lastUpdateTimestamp,
        uint256 distributionEnd,
        uint256 totalBalance
    ) internal view returns (uint256 newIndex) {
        if (
            emissionPerSecond == 0 ||
            totalBalance == 0 ||
            lastUpdateTimestamp == block.timestamp ||
            lastUpdateTimestamp >= distributionEnd
        ) {
            return currentIndex;
        }

        uint256 currentTimestamp = block.timestamp > distributionEnd ? distributionEnd : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;

        newIndex = emissionPerSecond * timeDelta * TEN_POW_PRECISION;
        unchecked { newIndex /= totalBalance; }
        newIndex += currentIndex;
    }

    function _shareToken() internal view virtual returns (IERC20 shareToken) {
        shareToken = IERC20(NOTIFIER);
    }

    function _getScaledUserBalanceAndSupply(address _user)
        internal
        view
        virtual
        returns (uint256 userBalance, uint256 totalSupply)
    {
        userBalance = _shareToken().balanceOf(_user);
        totalSupply = _shareToken().totalSupply();
    }
}
