// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

import {IDistributionManager} from "./IDistributionManager.sol";
import {DistributionTypes} from "../lib/DistributionTypes.sol";

interface ISiloIncentivesController is IDistributionManager {
    event RewardsAccrued(address indexed user, address indexed rewardToken, bytes32 indexed programId, uint256 amount);
    event ClaimerSet(address indexed user, address indexed claimer);
    event IncentivesProgramCreated(bytes32 indexed programId, string indexed name);
    event IncentivesProgramUpdated(bytes32 indexed programId);

    event RewardsClaimed(
        address indexed user,
        address indexed to,
        address indexed rewardToken,
        bytes32 programId,
        address claimer,
        uint256 amount
    );

    error InvalidDistributionEnd();
    error InvalidConfiguration();
    error IndexOverflowAtEmissionsPerSecond();
    error InvalidToAddress();
    error InvalidUserAddress();
    error ClaimerUnauthorized();
    error InvalidRewardToken();
    error IncentivesProgramAlreadyExists();
    error InvalidIncentivesProgramName();
    error IncentivesProgramNotFound();

    /**
     * @dev Silo share token event handler
     * @param _sender The address of the sender
     * @param _senderBalance The balance of the sender
     * @param _recipient The address of the recipient
     * @param _recipientBalance The balance of the recipient
     * @param _totalSupply The total supply of the asset in the lending pool
     * @param _amount The amount of the transfer
     */
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;

    /**
     * @dev Immediately distributes rewards to the incentives program
     * @param _programId The id of the incentives program
     * @param _amount The amount of rewards to distribute
     * @param _totalStaked The total staked amount
     */
    function immediateDistribution(bytes32 _programId, uint104 _amount, uint256 _totalStaked) external;

    /**
     * @dev Whitelists an address to claim the rewards on behalf of another address
     * @param _user The address of the user
     * @param _claimer The address of the claimer
     */
    function setClaimer(address _user, address _claimer) external;

    /**
     * @dev Creates a new incentives program
     * @param _incentivesProgramInput The incentives program creation input
     */
    function createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput memory _incentivesProgramInput)
        external;

    /**
     * @dev Updates an existing incentives program
     * @param _incentivesProgram The incentives program name
     * @param _distributionEnd The distribution end
     * @param _emissionPerSecond The emission per second
     */
    function updateIncentivesProgram(
        string calldata _incentivesProgram,
        uint40 _distributionEnd,
        uint104 _emissionPerSecond
    ) external;

    /**
     * @dev Called by the corresponding asset on any update that affects the rewards distribution
     * @param _incentivesProgramId The id of the incentives program being updated
     * @param _user The address of the user
     * @param _totalSupply The total supply of the asset in the lending pool
     * @param _userBalance The balance of the user of the asset in the lending pool
     */
    function handleAction(
        bytes32 _incentivesProgramId,
        address _user,
        uint256 _totalSupply,
        uint256 _userBalance
    ) external;

    /**
     * @dev Claims reward for an user to the desired address, on all the assets of the lending pool,
     * accumulating the pending rewards
     * @param _to Address that will be receiving the rewards
     * @return accruedRewards
     */
    function claimRewards(address _to) external returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for an user to the desired address, on all the assets of the lending pool,
     * accumulating the pending rewards
     * @param _to Address that will be receiving the rewards
     * @param _programIds The incentives program ids
     * @return accruedRewards
     */
    function claimRewards(address _to, bytes32[] calldata _programIds)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for an user to the desired address, on all the assets of the lending pool,
     * accumulating the pending rewards
     * @param _to Address that will be receiving the rewards
     * @param _programNames The incentives program names
     * @return accruedRewards
     */
    function claimRewards(address _to, string[] calldata _programNames)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending
     * rewards. The caller must be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
     * @param _user Address to check and claim rewards
     * @param _to Address that will be receiving the rewards
     * @return accruedRewards
     */
    function claimRewardsOnBehalf(address _user, address _to)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending
     * rewards. The caller must be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
     * @param _user Address to check and claim rewards
     * @param _to Address that will be receiving the rewards
     * @param _programIds The incentives program ids
     * @return accruedRewards
     */
    function claimRewardsOnBehalf(address _user, address _to, bytes32[] calldata _programIds)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending
     * rewards. The caller must be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
     * @param _user Address to check and claim rewards
     * @param _to Address that will be receiving the rewards
     * @param _programNames The incentives program names
     * @return accruedRewards
     */
    function claimRewardsOnBehalf(address _user, address _to, string[] calldata _programNames)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for msg.sender, on all the assets of the lending pool, accumulating the pending rewards
     * @return accruedRewards
     */
    function claimRewardsToSelf() external returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for msg.sender, on all the assets of the lending pool, accumulating the pending rewards
     * @param _programIds The incentives program ids
     * @return accruedRewards
     */
    function claimRewardsToSelf(bytes32[] calldata _programIds)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Claims reward for msg.sender, on all the assets of the lending pool, accumulating the pending rewards
     * @param _programNames The incentives program names
     * @return accruedRewards
     */
    function claimRewardsToSelf(string[] calldata _programNames)
        external
        returns (AccruedRewards[] memory accruedRewards);

    /**
     * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
     * @param _user The address of the user
     * @return The claimer address
     */
    function getClaimer(address _user) external view returns (address);

    /**
     * @dev Returns the total of rewards of an user, already accrued + not yet accrued
     * @param _user The address of the user
     * @param _programName The incentives program name
     * @return unclaimedRewards
     */
    function getRewardsBalance(address _user, string calldata _programName)
        external
        view
        returns (uint256 unclaimedRewards);

    /**
     * @dev Returns the total of rewards of an user, already accrued + not yet accrued
     * @param _user The address of the user
     * @param _programId The incentives program id
     * @return unclaimedRewards
     */
    function getRewardsBalance(address _user, bytes32 _programId) external view returns (uint256 unclaimedRewards);

    /**
     * @dev returns the unclaimed rewards of the user
     * @param _user the address of the user
     * @param _programName The incentives program name
     * @return the unclaimed user rewards
     */
    function getUserUnclaimedRewards(address _user, string calldata _programName) external view returns (uint256);
}
