// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

contract IRMZero is IInterestRateModel {
    /// @inheritdoc IInterestRateModel
    function initialize(address _irmConfig) external {}

    /// @inheritdoc IInterestRateModel
    function getCompoundInterestRateAndUpdate(uint256, uint256, uint256) external returns (uint256) {}

    /// @inheritdoc IInterestRateModel
    function getCompoundInterestRate(address, uint256) external view returns (uint256) {}

    /// @inheritdoc IInterestRateModel
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcur) {}

    /// @inheritdoc IInterestRateModel
    function decimals() external view returns (uint256) {}
}
