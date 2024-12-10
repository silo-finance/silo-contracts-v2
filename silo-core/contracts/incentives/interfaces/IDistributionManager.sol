// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

import {DistributionTypes} from "../lib/DistributionTypes.sol";

interface IDistributionManager {
    struct IncentivesProgram {
        uint256 index;
        address rewardToken; // can't be updated after creation
        uint104 emissionPerSecond; // configured by owner
        uint40 lastUpdateTimestamp;
        uint40 distributionEnd; // configured by owner
        mapping(address => uint256) users;
    }

    struct IncentiveProgramDetails {
        uint256 index;
        address rewardToken;
        uint104 emissionPerSecond;
        uint40 lastUpdateTimestamp;
        uint40 distributionEnd;
    }

    struct AccruedRewards {
        uint256 amount;
        bytes32 programId;
        address rewardToken;
    }

    event AssetConfigUpdated(address indexed asset, uint256 emission);
    event AssetIndexUpdated(address indexed asset, uint256 index);
    event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);
    event DistributionEndUpdated(bytes32 indexed incentivesProgram, uint256 newDistributionEnd);
    event IncentivesProgramIndexUpdated(bytes32 indexed programId, uint256 newIndex);
    event UserIndexUpdated(address indexed user, bytes32 indexed programId, uint256 newIndex);

    error OnlyNotifier();

    /**
     * @dev Sets the end date for the distribution
     * @param _incentivesProgram The incentives program name
     * @param _distributionEnd The end date timestamp
     */
    function setDistributionEnd(string calldata _incentivesProgram, uint40 _distributionEnd) external;

    /**
     * @dev Gets the end date for the distribution  
     * @param _incentivesProgram The incentives program name
     * @return The end of the distribution
     */
    function getDistributionEnd(string calldata _incentivesProgram) external view returns (uint256);

    /**
     * @dev Returns the data of an user on a distribution
     * @param _user Address of the user
     * @param _incentivesProgram The incentives program name
     * @return The new index
     */
    function getUserData(address _user, string calldata _incentivesProgram) external view returns (uint256);

    /**
     * @dev Returns the configuration of the distribution for a certain asset
     * @param _incentivesProgram The incentives program name
     * @return The index, the emission per second and the last updated timestamp
     */
    function getIncentivesProgramData(string calldata _incentivesProgram)
        external
        view
        returns (uint256, uint256, uint256, uint256);

    /**
     * @dev Returns the configuration of the distribution for a certain incentives program
     * @param _incentivesProgram The incentives program name
     * @return details The configuration of the incentives program
     */
    function incentivesProgram(string calldata _incentivesProgram)
        external
        view
        returns (IncentiveProgramDetails memory details);

    /**
     * @dev Returns the program id for the given program name
     * @param _programName The incentives program name
     * @return programId
     */
    function getProgramId(string calldata _programName) external pure returns (bytes32 programId);
}
