// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";

interface IFixedInterestRateModel is IInterestRateModel {
    struct InitConfig {
        uint256 apr;
        uint256 maturityTimestamp;
        address firmVault;
        IERC20 shareToken;
        address silo;
    }

    /// @dev Reverts when initialized with zero config address
    error ZeroConfig();
    /// @dev Reverts when functions are called for invalid silo address.
    error InvalidSilo();
    error OnlySilo();

    function accrueInterest() external returns (uint256 interest);
    function getConfig() external view returns (InitConfig memory config);
    function pendingAccrueInterest(uint256 _blockTimestamp) external view returns (uint256 interest);

    function getCurrentInterestRateDepositor(
        address _silo,
        uint256 _blockTimestamp
    ) external view returns (uint256 rcur);
}
