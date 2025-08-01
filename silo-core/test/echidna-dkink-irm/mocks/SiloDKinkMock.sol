// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

/// @title SiloDKinkMock
/// @notice Mock Silo contract for testing DynamicKinkModel Interest Rate Model
/// @dev Implements only the utilizationData() function that DynamicKinkModel reads
contract SiloDKinkMock {
    /// @notice Storage for utilization data
    ISilo.UtilizationData private _utilizationData;
    IInterestRateModel private _irm;

    /// @notice Error thrown when deploying SiloDKinkMock without deploying IRM first
    error SiloDKinkMock__DeployIrmFirst();

    /// @param _irmInput The IRM to use for testing (the same as we use in the tests)
    constructor(IDynamicKinkModel _irmInput) {
        require(address(_irmInput) != address(0), SiloDKinkMock__DeployIrmFirst());
        _irm = IInterestRateModel(address(_irmInput));
    }

    /// @notice Set collateral assets amount
    /// @param _collateralAssets Amount of collateral assets
    function setCollateralAssets(uint256 _collateralAssets) external {
        _utilizationData.collateralAssets = _collateralAssets;
    }

    /// @notice Set debt assets amount
    /// @param _debtAssets Amount of debt assets
    function setDebtAssets(uint256 _debtAssets) external {
        _utilizationData.debtAssets = _debtAssets;
    }

    /// @notice Set interest rate timestamp
    /// @param _interestRateTimestamp Timestamp of last interest rate update
    function setInterestRateTimestamp(uint64 _interestRateTimestamp) external {
        _utilizationData.interestRateTimestamp = _interestRateTimestamp;
    }

    /// @notice Set all utilization data at once
    /// @param _collateralAssets Amount of collateral assets
    /// @param _debtAssets Amount of debt assets
    /// @param _interestRateTimestamp Timestamp of last interest rate update
    function setUtilizationData(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint64 _interestRateTimestamp
    ) external {
        _irm.getCompoundInterestRateAndUpdate(
            _utilizationData.collateralAssets,
            _utilizationData.debtAssets,
            _utilizationData.interestRateTimestamp
        );

        _utilizationData = ISilo.UtilizationData({
            collateralAssets: _collateralAssets,
            debtAssets: _debtAssets,
            interestRateTimestamp: _interestRateTimestamp
        });
    }

    /// @notice Get utilization data
    /// @return The current utilization data
    function utilizationData() external view returns (ISilo.UtilizationData memory) {
        return _utilizationData;
    }
}
