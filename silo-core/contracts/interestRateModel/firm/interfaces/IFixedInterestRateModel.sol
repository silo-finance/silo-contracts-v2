// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

interface IFixedInterestRateModel is IInterestRateModel {
    struct Config {
        uint256 apr;
        uint256 maturityTimestamp;
        address firmVault;
        address shareToken;
        address silo;
    }

    event Initialized(address indexed config);

    /// @dev Reverts when initialized with zero config address
    error ZeroConfig();
    /// @dev Reverts when functions are called for invalid silo address.
    error InvalidSilo();
    error OnlySilo();

    function accrueInterest() external returns (uint256 interest);
    function accrueInterestView(uint256 _blockTimestamp) external view returns (uint256 interest);
    function capInterest(uint256 _interest, uint256 _blockTimestamp) external view returns (uint256 cappedInterest);
    function getCurrentInterestRateDepositor(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcur);
}
