// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/fixedInterestRateModel/interfaces/IFixedInterestRateModel.sol";

interface IFixedInterestRateModelConfig {
    function getConfig() external view returns (IFixedInterestRateModel.Config memory config);
}
