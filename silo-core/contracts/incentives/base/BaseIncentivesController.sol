// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {DistributionTypes} from "../lib/DistributionTypes.sol";
import {DistributionManager} from "./DistributionManager.sol";

/**
 * @title BaseIncentivesController
 * @notice Abstract contract template to build Distributors contracts for ERC20 rewards to protocol participants
 * @author Aave
  */
abstract contract BaseIncentivesController is DistributionManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(address user => mapping(bytes32 programId => uint256 unclaimedRewards)) internal _usersUnclaimedRewards;

    // this mapping allows whitelisted addresses to claim on behalf of others
    // useful for contracts that hold tokens to be rewarded but don't have any native logic to claim Liquidity Mining
    // rewards
    mapping(address => address) internal _authorizedClaimers;

    event RewardsAccrued(address indexed user, bytes32 indexed programId, uint256 amount);
    event RewardsClaimed(address indexed user, address indexed to, address indexed claimer, uint256 amount);
    event ClaimerSet(address indexed user, address indexed claimer);
    event IncentivesProgramCreated(bytes32 indexed incentivesProgramId);
    event IncentivesProgramUpdated(bytes32 indexed programId);

    error InvalidDistributionEnd();

    modifier onlyAuthorizedClaimers(address claimer, address user) {
        if (_authorizedClaimers[user] != claimer) revert ClaimerUnauthorized();

        _;
    }

    error InvalidConfiguration();
    error IndexOverflowAtEmissionsPerSecond();
    error InvalidToAddress();
    error InvalidUserAddress();
    error ClaimerUnauthorized();
    error InvalidRewardToken();
    error IncentivesProgramAlreadyExists();
    error InvalidIncentivesProgramName();
    error IncentivesProgramNotFound();

    constructor(address _owner, address _notifier) DistributionManager(_owner, _notifier) {}

    function createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput memory _incentivesProgramInput)
        external
        onlyOwner
    {
        require(bytes(_incentivesProgramInput.name).length > 0, InvalidIncentivesProgramName());

        bytes32 programId = keccak256(abi.encodePacked(_incentivesProgramInput.name));

        require(_incentivesProgramInput.rewardToken != address(0), InvalidRewardToken());
        require(_incentivesProgramIds.add(programId), IncentivesProgramAlreadyExists());

        incentivesPrograms[programId].rewardToken = _incentivesProgramInput.rewardToken;
        incentivesPrograms[programId].distributionEnd = _incentivesProgramInput.distributionEnd;
        incentivesPrograms[programId].emissionPerSecond = _incentivesProgramInput.emissionPerSecond;

        _updateAssetStateInternal(programId, _shareToken().totalSupply());

        emit IncentivesProgramCreated(programId);
    }

    function updateIncentivesProgram(
        string calldata _incentivesProgram,
        uint40 _distributionEnd,
        uint104 _emissionPerSecond
    ) external onlyOwner {
        require(_distributionEnd >= block.timestamp, InvalidDistributionEnd());

        bytes32 programId = keccak256(abi.encodePacked(_incentivesProgram));

        require(_incentivesProgramIds.contains(programId), IncentivesProgramNotFound());

        incentivesPrograms[programId].distributionEnd = _distributionEnd;
        incentivesPrograms[programId].emissionPerSecond = _emissionPerSecond;

        _updateAssetStateInternal(programId, _shareToken().totalSupply());

        emit IncentivesProgramUpdated(programId);
    }

    function handleAction(
        bytes32 incentivesProgramId,
        address user,
        uint256 totalSupply,
        uint256 userBalance
    ) public onlyNotifier {
        uint256 accruedRewards = _updateUserAssetInternal(incentivesProgramId, user, userBalance, totalSupply);

        if (accruedRewards != 0) {
            uint256 newUnclaimedRewards = _usersUnclaimedRewards[user][incentivesProgramId] + accruedRewards;
            _usersUnclaimedRewards[user][incentivesProgramId] = newUnclaimedRewards;
            emit RewardsAccrued(user, incentivesProgramId, newUnclaimedRewards);
        }
    }

    function getRewardsBalance(address _user, string calldata _programName)
        external
        view
        returns (uint256 unclaimedRewards)
    {
        bytes32 programId = keccak256(abi.encodePacked(_programName));
        unclaimedRewards = getRewardsBalance(_user, programId);
    }

    function getRewardsBalance(address user, bytes32 programId)
        public
        view
        returns (uint256 unclaimedRewards)
    {
        unclaimedRewards = _usersUnclaimedRewards[user][programId];

        (uint256 stakedByUser, uint256 totalStaked) = _getScaledUserBalanceAndSupply(user);

        unclaimedRewards += _getUnclaimedRewards(programId, user, stakedByUser, totalStaked);
    }

    function claimRewards(address to) external returns (AccruedRewards[] memory accruedRewards) {
        if (to == address(0)) revert InvalidToAddress();

        accruedRewards = _claimRewards(msg.sender, msg.sender, to);
    }

    function claimRewardsOnBehalf(address _user, address _to)
        external
        onlyAuthorizedClaimers(msg.sender, _user)
        returns (AccruedRewards[] memory accruedRewards)
    {
        if (_user == address(0)) revert InvalidUserAddress();
        if (_to == address(0)) revert InvalidToAddress();

        accruedRewards = _claimRewards(msg.sender, _user, _to);
    }

    function claimRewardsToSelf() external returns (AccruedRewards[] memory accruedRewards) {
        accruedRewards = _claimRewards(msg.sender, msg.sender, msg.sender);
    }

    function setClaimer(address user, address caller) external onlyOwner {
        _authorizedClaimers[user] = caller;
        emit ClaimerSet(user, caller);
    }

    function getClaimer(address user) external view returns (address) {
        return _authorizedClaimers[user];
    }

    function getUserUnclaimedRewards(address _user, string calldata _programName)
        external
        view
        returns (uint256)
    {
        bytes32 programId = keccak256(abi.encodePacked(_programName));
        return _usersUnclaimedRewards[_user][programId];
    }

    /**
     * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending rewards
     * @param claimer Address to check and claim rewards
     * @param user Address to check and claim rewards
     * @param to Address that will be receiving the rewards
     * @return accruedRewards claimed
     */
    function _claimRewards(
        address claimer,
        address user,
        address to
    ) internal returns (AccruedRewards[] memory accruedRewards) {
        accruedRewards = _accrueRewards(user);

        for (uint256 i = 0; i < accruedRewards.length; i++) {
            uint256 unclaimedRewards = _usersUnclaimedRewards[user][accruedRewards[i].programId];
            accruedRewards[i].amount += unclaimedRewards + accruedRewards[i].amount;

            if (accruedRewards[i].amount != 0) {
                emit RewardsAccrued(user, accruedRewards[i].programId, accruedRewards[i].amount);

                _transferRewards(accruedRewards[i].rewardToken, to, accruedRewards[i].amount);
                emit RewardsClaimed(user, to, claimer, accruedRewards[i].amount);
            }
        }
    }

    /**
     * @dev Abstract function to transfer rewards to the desired account
     * @param rewardToken Reward token address
     * @param to Account address to send the rewards
     * @param amount Amount of rewards to transfer
     */
    function _transferRewards(address rewardToken, address to, uint256 amount) internal virtual {
        IERC20(rewardToken).transfer(to, amount);
    }
}
