// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IInterestRateModel} from "./IInterestRateModel.sol";

interface IInterestRateModelConfig {
    function getConfig() external view returns (IInterestRateModel.Config memory config);
}
