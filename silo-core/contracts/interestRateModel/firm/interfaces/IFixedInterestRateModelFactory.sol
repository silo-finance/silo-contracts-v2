// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    IFixedInterestRateModel, IInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModel.sol";

interface IFixedInterestRateModelFactory {
    event NewFixedInterestRateModel(IFixedInterestRateModel indexed irm);
    error InvalidMaturityTimestamp();

    function create(
        IFixedInterestRateModel.Config calldata _config,
        bytes32 _externalSalt
    ) external returns (IFixedInterestRateModel irm);

    function createdInFactory(address _irm) external view returns (bool);

    /// @notice Predicts the address of the FixedInterestRateModel.
    /// @param _creator The creator address.
    function predictFixedInterestRateModelAddress(address _creator, bytes32 _externalSalt)
        external
        view
        returns (address addr);
}
