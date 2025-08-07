// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    IFixedInterestRateModel, IInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModel.sol";

interface IFixedInterestRateModelFactory {
    event NewFixedInterestRateModel(IFixedInterestRateModel indexed irm);
    function create(IFixedInterestRateModel.Config calldata _config) external view returns (IInterestRateModel irm);
    function verifyConfig(IFixedInterestRateModel.Config calldata _config) external view;
}
